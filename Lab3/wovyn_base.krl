ruleset wovyn_base {
  meta {
    shares __testing
    use module twilio_keys
    use module twilio_db alias twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "heeartbeat",
                              "attrs": [ "temp", "baro" ] } ] }
    temperature_threshold = 80
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
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      message = "Temperature Violation: device reached " + temp + " degrees at " + time
    }

    twilio:send_sms(to, from, message)
  }
}
