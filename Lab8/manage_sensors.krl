ruleset manage_sensors {
  meta {
    shares __testing, all_sensor_temps, temp_sensors, top_reports
    use module io.picolabs.subscription alias Subs
    use module sensor_profile alias manager_profile
    use module twilio_keys
    use module twilio_db alias twilio
      with account_sid = keys:twilio{"account_sid"}
          auth_token = keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } , {"name": "temp_sensors"}, {"name": "all_sensor_temps"}, {"name": "top_reports"}],
                  "events": [
                    { "domain": "sensor", "type": "new_sensor",
                              "attrs": [ "name" ] },
                    { "domain": "report", "type": "request" },
                    { "domain": "sensor", "type": "unneeded_sensor",
                              "attrs": [ "name" ] },
                    { "domain": "sensor", "type": "new_subscription",
                              "attrs": [ "host","name", "eci" ]}
                  ]
                }
    temp_sensors = function() {
      // query by subscirption with temperature sensor role instead
      Subs:established("Rx_role", "temp_sensor").map(function(sub) {
        url = "http://192.168.1.8:8080/sky/cloud/" + sub{"Tx"} + "/sensor_profile/get_user_profile";
        {
          "name": http:get(url){"content"}.decode(){"name"},
          "subscription info": sub,
        }
      })
    }

    all_sensor_temps = function() {
      sensors().map(function(sensor) {
        url = "http://192.168.1.8:8080/sky/cloud/" + sensor{"subscription info"}{"Tx"} + "/temperature_store/temperatures";
        {
          "temps": http:get(url){"content"}.decode()
        }
      })
    }

    top_reports = function() {
      lowerBound = ent:currId - 5;
      top = ent:finished_reports.filter(function(v,k){k >= lowerBound});
      top;
    }

    default_threshold = 72
    default_to = "+16512300419"
  }

  // open up a new report
  rule request_report {
    select when report request
    always {
      ent:currId := ent:currId.isnull() => 1 | ent:currId;
      rcn = ent:currId;
      ent:all_reports := ent:all_reports.isnull() => {} | ent:all_reports;
      ent:all_reports{rcn} := {"temperature_sensors": temp_sensors().length(), "responding": 0, "temperatures": []};
      ent:currId := ent:currId + 1;
      raise report event "start"
        attributes {"rcn": rcn}
    }
  }

  // sends event to each sensor to start a report
  rule start_report {
    select when report start
    foreach temp_sensors() setting (temp_sensor)
      pre {
        rcn = event:attr("rcn")
        tx = temp_sensor{"subscription info"}{"Tx"}
        rx = temp_sensor{"subscription info"}{"Rx"}
      }
      event:send({
        "eci": tx,
        "domain": "sensor",
        "type": "start_report",
        "attrs":{
          "rcn": rcn,
          "Rx": rx
        }
      })
  }

  rule catch_temperature_reports {
    select when report temperature_report_created
    pre {
      temps = event:attr("temps")
      rcn = event:attr("rcn")
      name = event:attr("name")
      report = ent:all_reports{rcn}
    }

    always {
      responding_num = report{"responding"} + 1;
      report = report.set(["temperatures"], report{"temperatures"}.append({"name": name, "temps": temps}));
      report = report.set(["responding"], responding_num);
      ent:all_reports{rcn} := report;
      raise report event "temperature_report_added" attributes {"rcn": rcn};
    }
  }

  rule check_report_status {
    select when report temperature_report_added
    pre {
      rcn = event:attr("rcn")
      report = ent:all_reports{rcn}
      expected = report{"temperature_sensors"}
      actual = report{"responding"}
    }

    if(expected == actual) then
      send_directive("Report Finished", {"rcn":rcn})

    fired {
      ent:finished_reports := ent:finished_reports.isnull() => {} | ent:finished_reports;
      ent:finished_reports{rcn} := report;
    }
  }

  rule clear_reports {
    select when report clear
    always {
      clear ent:all_reports;
      clear ent:finished_reports;
      clear ent:currId;
    }
  }

  rule create_new_sensor {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then
      send_directive("sensor name is already taken", {"name":name})
    notfired {
      raise wrangler event "child_creation"
        attributes { "name": name, "color": "#ffff00", "rids": ["wovyn_base","sensor_profile","temperature_store"] }
    }
  }

  // Rx is its own channel for recieving (recieve queries and events)
  // Tx is the other picos cahnnel for transmitting (make and send queries and events)


  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      this_sensor = {"id": event:attr("id"), "eci": event:attr("eci")}
      name = event:attr("name")
    }
    event:send(
      {
        "eci": this_sensor{"eci"},
        "eid": "update_profile",
        "domain": "sensor",
        "type": "profile_updated",
        "attrs": {
          "threshold": default_threshold,
          "location": "",
          "name": name,
          "to": default_to,
        }
      }
    )
    always {
      ent:sensors := ent:sensors.defaultsTo({});
      ent:sensors{[name]} := this_sensor;
      raise wrangler event "subscription" attributes {
        "name": name,
        "wellKnown_Tx": this_sensor{"eci"},
        "Rx_role":"temp_sensor",
        "Tx_role":"manager",
        "channel_type":"subscription",
      } // create subscription to the child pico, use a distinctive role
      // change env variable to find sensor picos by subscription instead
    }
  }

  rule subscribe_existing_sensor {
    select when sensor new_subscription
    pre {
      host = event:attr("host")
      name = event:attr("name")
      eci = event:attr("eci")
    }

    always {
      raise wrangler event "subscription" attributes {
        "name": name,
        "wellKnown_Tx": eci,
        "Rx_role": "temp_sensor",
        "Tx_role": "manager",
        "Tx_host": host,
        "channel_type": "subscription",
      }
    }
  }

  rule sub_threshold_violation {
    select when sensor threshold_violation
    pre {
      temp = event:attr("temperature").klog("temp")
      time = event:attr("timestamp").klog("time")
      message = "Temperature Violation: device reached " + temp + " degrees at " + time
      to = manager_profile:get_user_profile(){"to"}.klog(to)
    }

    twilio:send_sms(to, from, message)
  }

  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }

    if exists then
      send_directive("deleting sensor",{"name":name})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name": name};
      ent:sensors := ent:sensors.delete([name]);
    }
  }
}
