ruleset twilio_db {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    shares __testing, send_sms, messages
    provides send_sms, messages
  }
  global {
    send_sms = defaction(to, from, message) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      http:post(base_url + "Messages.json", form =
                {"From":from,
                 "To":to,
                 "Body":message
                })
    }

    messages = function(size, to, from) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>;
      params = {};
      params = ((size != null) => params.put({"PageSize":size}) | params).klog("size: ");
      params = ((to != null) => params.put({"To":to}) | params).klog("to: ");
      params = ((from != null) => params.put({"From":from}) | params).klog("from: ");

      resp = http:get(base_url + "Messages.json", params);
      resp.get(["content"]).decode()
    }
    __testing = {
      "queries": [ { "name": "send_sms", "args": [ "to","from","message","account_sid","auth_token" ] }, { "name": "__testing" } ],
      "events": [ { "domain": "test", "type": "new_message" } ]
    }
  }
}
