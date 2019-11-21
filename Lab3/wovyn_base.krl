ruleset wovyn_base {
  meta {
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "heeartbeat",
                              "attrs": [ "temp", "baro" ] } ] }
  }

  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      never_used = event:attrs().klog("attrs")
      info = event:attr("genericThing")
    }

    if not info.isnull() then
    send_directive("say", {
      "message": "Hello World",
      "temp": info
    })
  }
}
