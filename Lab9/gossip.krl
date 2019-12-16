ruleset gossip {
  meta {
    shares getMessages, getPeer, getSeq, getUnseenMessages, prepareSeen,
      prepareRumor, prepareMessage, addMySeen, addPeerSeen, send, messageNotAlreadyReceived, __testing
    use module io.picolabs.subscription alias Subs
  }
  global {
    __testing = { "queries": [ { "name": "__testing" }, { "name": "getMessages"} ],
                  "events": [ { "domain": "gossip", "type": "seen",
                              "attrs": [ "message", "sender" ] } ] }

       // use Tx_role and Rx_role in each subscription to simply be "node".

    // use the current state to figure out which peer to send to
    // choose a peer that needs something from you
    // if last seen message indicates its seen everything then dont send to them
    getMessages = function() {
      ent:all_messages
    }

    getPeer = function() {
      subs = Subs:established("Rx_role","node");
      rand_sub = random:integer(subs.length() - 1);
      rand_sub;
    }

    getPeerSeen = function() {
      ent:peer_seen
    }

    getSeq = function(messageID) {
      seq = messageID.split(":")[1].as("Number");
      seq;
    }

    // returns a list of messages a peer hasn't seen
    getUnseenMessages = function(peer_id) {
      peer_seen = ent:peer_seen.get(peer_id);
      unseen = ent:all_messages.filter(function(rumor) {
        curr_picoid = rumor{"SensorID"};
        curr_seq = peer_seen{curr_picoid};
        my_seq = getSeq(rumor{"MessageID"});

        peer_seq = peer_seen.isnull() || curr_seen.isnull() => 0 | curr_seq;
        add = (my_seq > peer_seq) => true | false;
        add;
      })
    }

    prepareSeen = function() {
      // make a map that maps pico id's to the max num of messages you've seen
      ent:seen
    }

    // look at peer seen to see what you should send, update peer_seen here as well
    prepareRumor = function(peer) {
      peer_id = peer{"Tx"};
      unseen = getUnseenMessages(peer_id);
      rumor = unseen[0];

      // add to peer_seen
      addPeerSeen(peer_id, getSeq(rumor{"MessageID"}), rumor{"SensorID"});
      rumor
    }

    // return message, randomly choose a message type
    prepareMessage = function(peer) {
      type = random:integer(1);
      message = (type == 1) => prepareSeen() | prepareRumor(peer);
      obj = {"message": message, "type": type};
      obj
    }

    // update state of who has been sent what
    addMySeen = function(originId, seq) {
      max = ent:seen.get(originId).defaultsTo(0);
      new_max = (seq - max == 1) => seq | max;
      ent:seen.put(origin, new_max);
    }

    addPeerSeen = function(peerId, seq, sensorId) {
      // set the default if it has not been initialized
      peer_seen = getPeerSeen().get(peerId).defaultsTo({});
      old_seq = getPeerSeen().get([peerId, sensorId]).defaultsTo(0);

      new_seq = (seq - old_seq == 1) => seq | old_seq;
      getPeerSeen().klog("peer seen before adding peer seen: ");
      getPeerSeen().put([peerId, sensorId], new_seq).klog("peer seen after: ");
    }

    // send the message to the peer
    send = function(message, peer, type) {
      event:send(
              { "eci": peer{"Tx"}, "eid": "gossip_message",
                  "domain": "gossip", "type": type,
                  "attrs": {"message": message, "sender": {"picoId": meta:picoId, "Rx": peer{"Rx"}, "Tx": peer{"Tx"}}}
              }
          )
    }

    messageNotAlreadyReceived = function(message) {
      match = ent:all_messages.filter(function(msg) {
        msg{"MessageID"} == message{"MessageID"}
      });

      exists = (match.length()) == 0 => true | false;
      exists
    }
  }



  // setup that responds to a startup event and
  // sets the schedule for the pico have this trigger
  rule initialization {
    select when wrangler ruleset_added
    always {
      schedule gossip event "heartbeat" repeat "*/5  *  * * * *"
    }
  }

  // scheduled event in the pico will periodically send itself a gossip_heartbeat event
  // sends a message to one of the picos subs
  rule gossip_heartbeat {
    select when gossip heartbeat
    pre {
      subscriber = getPeer()
      obj = prepareMessage(subscriber)
      m = obj{"message"}
      type = (obj{"type"} == 1) => "seen" | "rumor"
    }

    if not m.isnull() then
      event:send ({
        "eci": subscriber{"Tx"},
        "eid": "gossip_message",
        "domain": "gossip",
        "type": type,
        "attrs": {"message": m, "sender": {"picoId": meta:picoId, "Rx": subscriber{"Tx"}, "Tx": subscriber{"Rx"}}}
      });
  }

  rule respond_to_rumor {
    select when gossip rumor
    pre {
      msg = event:attr("message")
      seq = getSeq(msg{"MessageID"})
      sensorId = msg{"SensorID"}
    }

    if messageNotAlreadyReceived(msg) then
      noop();

    fired {
      ent:all_messages := ent:all_messages.append(msg);
      addMySeen(sensorId, seq);
    }
    // store rumor in ent var, if you havent seen that
    // high yet then make sure to not report it as the highest sequence
    // when sending a seen message
  }

  rule respond_to_seen {
    select when gossip seen

    pre {
      message = event:attr("message")
      sender = event:attr("sender")
      originId = message{"originId"}
      peerId = sender{"Tx"}
    }
    // update peer_seen

    always {
      ent:peer_seen := ent:peer_seen.put(peerId, message);
      raise gossip event "seen_resp" attributes {"sender": sender};
    }
    // check for any rumors not in the message and send them
    // as rumors back
  }

  rule send_unseen {
    select when gossip seen_resp
    foreach getUnseenMessages(peerId) setting (msg)
      pre {
        sender = event:attr("sender")
        peerId = sender{"Tx"}
      }
      event:send ({
        "eci": sender{"Rx"},
        "eid": "gossip_rep",
        "domain": "gossip",
        "type": "rumor",
        "attrs": {"message": msg, "sender": {"picoId": meta:picoId, "Rx": sender{"Tx"}, "Tx": sender{"Rx"}}}
      })
  }
}
