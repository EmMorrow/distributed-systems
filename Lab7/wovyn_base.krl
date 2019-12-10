ruleset wovyn_base {
  meta {
    shares __testing
    use module twilio_keys
    use module twilio_db alias twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
    use module sensor_profile
    use module io.picolabs.subscription alias Subs
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "heeartbeat",
                              "attrs": [ "temp", "baro" ] } ] }
    to = "+16512300419"
    from = "+17244714384"
  }

  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      info = event:attr("genericThing")
      temp = event:attr("genericThing")["data"]["temperature"][0]["temperatureF"]
    }

    if not info.isnull() then
      send_directive("processed heartbeat", {
        "temp": temp
      })
    fired {
      raise wovyn event "new_temperature_reading"
        attributes {"temperature": temp, "timestamp": time:now()}
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temperature_threshold = sensor_profile:get_user_profile(){"threshold"}
      temp = event:attr("temperature").klog("find high temps, temp ")
      time = event:attr("timestamp")
      message = ((temp > temperature_threshold) => "There has been a violation" | "There has been no violation")
    }

    send_directive("violation", {
      "message": message
    })
    fired {
      raise wovyn event "threshold_violation" attributes {
        "temperature": temp,
        "timestamp": time
      } if (temp > temperature_threshold);
    }

  }

  rule threshold_notification {
    select when wovyn threshold_violation
    foreach Subs:established("Rx_role", "manager") setting (sub)
      event:send({
        "eci": sub{"Tx"},
        "domain": "sensor",
        "type": "threshold_violation",
        "attrs": event:attrs,
      })
  }
}
