ruleset manage_sensors {
  meta {
    shares __testing, all_sensor_temps, sensors
    use module io.picolabs.subscription alias Subs
    use module sensor_profile alias manager_profile
    use module twilio_keys
    use module twilio_db alias twilio
      with account_sid = keys:twilio{"account_sid"}
          auth_token = keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } , {"name": "sensors"}, {"name": "all_sensor_temps"}],
                  "events": [
                    { "domain": "sensor", "type": "new_sensor",
                              "attrs": [ "name" ] },
                    { "domain": "sensor", "type": "unneeded_sensor",
                              "attrs": [ "name" ] },
                    { "domain": "sensor", "type": "new_subscription",
                              "attrs": [ "host","name", "eci" ]}
                  ]
                }
    sensors = function() {
      // query by subscirption with temperature sensor role instead
      Subs:established("Rx_role", "sensor").map(function(sub) {
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

    default_threshold = 72
    default_to = "+16512300419"
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
        "Rx_role":"sensor",
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
        "Rx_role": "sensor",
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
