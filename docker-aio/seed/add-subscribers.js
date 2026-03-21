db.subscribers.updateOne(
  { imsi: "001010000000001" },
  {
    $set: {
      imsi: "001010000000001",
      msisdn: ["0100000001"],
      ambr: {
        downlink: { value: 1, unit: 3 },
        uplink: { value: 1, unit: 3 }
      },
      slice: [
        {
          sst: 1,
          sd: "000001",
          default_indicator: true,
          session: [
            {
              name: "internet",
              type: 3,
              ambr: {
                downlink: { value: 1, unit: 3 },
                uplink: { value: 1, unit: 3 }
              },
              qos: {
                index: 9,
                arp: {
                  priority_level: 8,
                  pre_emption_vulnerability: 1,
                  pre_emption_capability: 1
                }
              }
            }
          ]
        }
      ],
      security: {
        k: "465B5CE8B199B49FAA5F0A2EE238A6BC",
        opc: "E8ED289DEBA952E4283B54E88E6183CA",
        amf: "8000",
        sqn: NumberLong(16)
      },
      subscribed_rau_tau_timer: 12,
      network_access_mode: 0,
      subscriber_status: 0,
      operator_determined_barring: 0,
      access_restriction_data: 32
    }
  },
  { upsert: true }
);

db.subscribers.updateOne(
  { imsi: "001010000000002" },
  {
    $set: {
      imsi: "001010000000002",
      msisdn: ["0100000002"],
      ambr: {
        downlink: { value: 1, unit: 3 },
        uplink: { value: 1, unit: 3 }
      },
      slice: [
        {
          sst: 2,
          sd: "000002",
          default_indicator: true,
          session: [
            {
              name: "streaming",
              type: 3,
              ambr: {
                downlink: { value: 1, unit: 3 },
                uplink: { value: 1, unit: 3 }
              },
              qos: {
                index: 9,
                arp: {
                  priority_level: 8,
                  pre_emption_vulnerability: 1,
                  pre_emption_capability: 1
                }
              }
            }
          ]
        }
      ],
      security: {
        k: "B199B49F465B5CE8E238A6BCAA5F0A2E",
        opc: "283B54E8E8ED289D8E6183CAEBA952E4",
        amf: "8000",
        sqn: NumberLong(16)
      },
      subscribed_rau_tau_timer: 12,
      network_access_mode: 0,
      subscriber_status: 0,
      operator_determined_barring: 0,
      access_restriction_data: 32
    }
  },
  { upsert: true }
);

print("Added UERANSIM subscribers:");
print(" - 001010000000001 -> internet / 1-000001");
print(" - 001010000000002 -> streaming / 2-000002");
