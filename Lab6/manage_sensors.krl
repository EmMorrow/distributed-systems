ruleset manage_sensors {
  meta {
    provides get_user_profile
    shares get_user_profile
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [
                    { "domain": "sensor", "type": "new_sensor",
                              "attrs": [ "name" ] },
                    { "domain": "sensor", "type": "unneeded_sensor",
                              "attrs": [ "name" ] },
                  ]
                }
    sensors = function() {
      env:sensors
    }

    default_threshold = 75
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

  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      this_sensor = {"id": event:attr("id"), "eci": event:attr("eci")}
      name = event:attr("rs_attrs") {"name"}
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
    }
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
