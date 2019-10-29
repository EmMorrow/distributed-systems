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

    messages = function(to, from) {

    }
    __testing = {
      "queries": [ { "name": "send_sms", "args": [ "to","from","message","account_sid","auth_token" ] }, { "name": "__testing" } ],
      "events": [ { "domain": "test", "type": "new_message" } ]
    }
  }
}
