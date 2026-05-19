-- Backfill remaining UTC event time zones using audited event-local mappings.
-- Also patch known missing/incorrect location fields for a few imported events.
UPDATE "events"
SET
  "time_zone" = CASE "id"
    WHEN '58c8a84f-9db2-4dee-81f5-ba4ea8311f51' THEN 'Asia/Bangkok'
    WHEN '1f2c9821-d128-4053-a0cf-dc4b786e8e46' THEN 'Asia/Bangkok'
    WHEN '5ac763fa-239e-4e17-9dc3-f8a8828a7833' THEN 'America/Bogota'
    WHEN 'ea260227-1d1c-4d60-b345-2b9d6b434b40' THEN 'Asia/Seoul'
    WHEN '201a2ac3-a8fa-4bd8-a5d3-5cef67058cfa' THEN 'Asia/Tokyo'
    WHEN '5e5509ba-6676-45d1-9646-d8f365cfbda3' THEN 'Europe/London'
    WHEN '4d2b518d-b9d1-4923-a1a7-0deb50bda388' THEN 'Europe/Brussels'
    WHEN '7615ea35-71fa-428e-b839-737606db6252' THEN 'Asia/Seoul'
    WHEN 'bed3e78a-188c-4b08-9fbe-2a8a23b0b62d' THEN 'Europe/Zagreb'
    WHEN 'fba399c8-b0ec-4373-99b5-70e4f5fcbbd3' THEN 'America/Lima'
    WHEN 'd4ce2095-e10e-4f18-b161-21d68cac4a13' THEN 'Africa/Johannesburg'
    WHEN '38549138-696b-46b3-a669-ca0b8e83d4cf' THEN 'Africa/Johannesburg'
    WHEN 'e4d203f3-4e3a-4273-a311-df5b71616568' THEN 'Asia/Bangkok'
    WHEN 'ab7d85ea-7c56-4f7a-9568-666dc475aa1d' THEN 'Europe/Paris'
    WHEN '5b95c35d-9bf9-4560-8431-f26c5f2b5646' THEN 'Asia/Bangkok'
    WHEN '62440636-1e2e-4a6b-8db5-fce93bb1b726' THEN 'Asia/Bangkok'
    WHEN '855b704d-7c87-4b51-9905-8691f7b4ec02' THEN 'Asia/Riyadh'
    WHEN '2e378ca0-0598-4880-be57-a4ef408acba4' THEN 'Asia/Dubai'
    WHEN 'dd617de9-2642-47cc-882e-350e18a0de87' THEN 'Asia/Seoul'
    WHEN 'c18d007d-c4c6-4a45-b887-27d063dbe5b8' THEN 'Asia/Tokyo'
    WHEN '1cc106b7-2158-4c58-946e-31d09472fc1d' THEN 'Asia/Tokyo'
    WHEN '6ed8bd48-ed76-42aa-9f59-7412310352be' THEN 'Europe/Paris'
    WHEN '32b234ea-90e4-4bd6-ab88-86e17cec4f2b' THEN 'Europe/Brussels'
    WHEN '88147c57-703e-4fb5-8cb5-f70dff2d3dd8' THEN 'Asia/Seoul'
    WHEN 'f1cced9a-6a21-44cf-8244-bac4dec14148' THEN 'Europe/Zagreb'
    WHEN '222306d8-50cc-4485-8816-2deb695bf630' THEN 'Asia/Tokyo'
    WHEN 'c5341fd9-f2bf-4528-ba71-7c796a0e0617' THEN 'Europe/Amsterdam'
    WHEN '573be9d7-a7a7-4194-8c47-2f39e441e389' THEN 'Asia/Seoul'
    WHEN 'b38739cb-bad2-4b88-be1e-cd1d0ac26326' THEN 'Africa/Johannesburg'
    WHEN 'abc70d74-a9ce-4133-9c99-b549af8a7adc' THEN 'Africa/Johannesburg'
    WHEN 'a290903b-cb7f-4878-a7d8-a3946ca2dfac' THEN 'Asia/Seoul'
    WHEN '65a19668-51fe-451d-b084-2934ebecb03a' THEN 'America/Lima'
    WHEN '89da84d7-9b3a-4af6-97bc-38a2b9dfbd18' THEN 'Asia/Bangkok'
    WHEN 'a8e7692a-7a98-43f9-8625-086c014c7526' THEN 'Asia/Bangkok'
    WHEN 'be87b197-a6f4-41b7-bbe9-42a8f9addd50' THEN 'Europe/Paris'
    WHEN '03969a51-597e-4ec6-8c46-10f45c8a4727' THEN 'Asia/Bangkok'
    WHEN 'e6f34d6e-ece2-477c-aafc-e60e7015e738' THEN 'Asia/Tokyo'
    WHEN 'e331514a-b14c-4315-8bb0-387ea19c17eb' THEN 'Europe/London'
    WHEN 'ba4703be-e469-4fb3-bf9b-36b99799a95e' THEN 'Asia/Tokyo'
    WHEN 'da6dba2b-edec-4f3d-8a2f-da718107b2d9' THEN 'Europe/Brussels'
    WHEN 'db8972a8-c0d9-4749-9c3e-3b69ce0cb230' THEN 'Europe/Zagreb'
    WHEN 'e9629aa9-6449-428d-8a1f-cc35e32ca529' THEN 'Asia/Seoul'
    WHEN '11edb754-ca36-4037-a7be-9bb26f0569fd' THEN 'Asia/Bangkok'
    WHEN '69eacf9d-379e-4423-a569-675b6f8225a3' THEN 'Europe/Paris'
    WHEN '14d99e95-0bf6-4b7f-9775-8fc9a11863ce' THEN 'Africa/Johannesburg'
    WHEN 'bb442b7e-ed5b-41ae-81d1-9f173fb2437a' THEN 'Africa/Johannesburg'
    WHEN 'd385f551-0b98-4569-97da-f92e948497f8' THEN 'Asia/Tokyo'
    WHEN '1311d65b-0439-47a1-a2fb-8fc1aa0afb22' THEN 'Europe/London'
    WHEN 'e3d3957b-085c-443d-8e29-4864a64cb8c4' THEN 'Europe/Brussels'
    WHEN 'e8ffcd33-2d2c-4910-af63-6714b030a2b6' THEN 'Europe/Zagreb'
    WHEN 'b14d4ff2-e70f-4dab-a2b4-cb796a9995c4' THEN 'Europe/London'
    WHEN '0d9d56af-55fa-4feb-bcdc-2358130aaaba' THEN 'America/Lima'
    WHEN '5aceaf9f-7eb9-4050-9480-70a9ddee615c' THEN 'Asia/Tokyo'
    WHEN 'af9c7cd0-9f8c-43e5-9eb2-dfa9a4c91c43' THEN 'Europe/Paris'
    WHEN 'f79b8c37-fc5b-4607-8e6c-51d4d687c971' THEN 'Africa/Johannesburg'
    WHEN 'ad79bd36-6ca0-48b4-a295-66f708ac2316' THEN 'Africa/Johannesburg'
    WHEN '89406cf1-3c94-4f3f-b5a0-8167f8bcc345' THEN 'Asia/Dubai'
    WHEN '23728abc-6a6e-4bd2-b545-716ce3f124cf' THEN 'Asia/Seoul'
    WHEN '6d074d52-2cb4-43a0-9107-f0d9ac25adcd' THEN 'Asia/Tokyo'
    WHEN '6168fd10-cb49-439d-bfac-5e4bf71b8deb' THEN 'Europe/Brussels'
    WHEN 'ff596c74-a35c-4099-af08-35411759b0eb' THEN 'Europe/Zagreb'
    ELSE "time_zone"
  END,
  "city" = CASE "id"
    WHEN '855b704d-7c87-4b51-9905-8691f7b4ec02' THEN '利雅得'
    WHEN '65a19668-51fe-451d-b084-2934ebecb03a' THEN '利马'
    WHEN '11edb754-ca36-4037-a7be-9bb26f0569fd' THEN '曼谷'
    ELSE "city"
  END,
  "venue_name" = CASE "id"
    WHEN '855b704d-7c87-4b51-9905-8691f7b4ec02' THEN 'Banban Desert'
    WHEN '65a19668-51fe-451d-b084-2934ebecb03a' THEN 'Costa 21'
    WHEN '11edb754-ca36-4037-a7be-9bb26f0569fd' THEN 'Live Park Rama 9'
    ELSE "venue_name"
  END,
  "venue_address" = CASE "id"
    WHEN '855b704d-7c87-4b51-9905-8691f7b4ec02' THEN 'Banban Desert, Riyadh, Saudi Arabia'
    WHEN '65a19668-51fe-451d-b084-2934ebecb03a' THEN 'Costa Verde / Costa 21, Lima, Peru'
    WHEN '11edb754-ca36-4037-a7be-9bb26f0569fd' THEN 'Live Park Rama 9, Bangkok, Thailand'
    ELSE "venue_address"
  END
WHERE "id" IN (
  '58c8a84f-9db2-4dee-81f5-ba4ea8311f51',
  '1f2c9821-d128-4053-a0cf-dc4b786e8e46',
  '5ac763fa-239e-4e17-9dc3-f8a8828a7833',
  'ea260227-1d1c-4d60-b345-2b9d6b434b40',
  '201a2ac3-a8fa-4bd8-a5d3-5cef67058cfa',
  '5e5509ba-6676-45d1-9646-d8f365cfbda3',
  '4d2b518d-b9d1-4923-a1a7-0deb50bda388',
  '7615ea35-71fa-428e-b839-737606db6252',
  'bed3e78a-188c-4b08-9fbe-2a8a23b0b62d',
  'fba399c8-b0ec-4373-99b5-70e4f5fcbbd3',
  'd4ce2095-e10e-4f18-b161-21d68cac4a13',
  '38549138-696b-46b3-a669-ca0b8e83d4cf',
  'e4d203f3-4e3a-4273-a311-df5b71616568',
  'ab7d85ea-7c56-4f7a-9568-666dc475aa1d',
  '5b95c35d-9bf9-4560-8431-f26c5f2b5646',
  '62440636-1e2e-4a6b-8db5-fce93bb1b726',
  '855b704d-7c87-4b51-9905-8691f7b4ec02',
  '2e378ca0-0598-4880-be57-a4ef408acba4',
  'dd617de9-2642-47cc-882e-350e18a0de87',
  'c18d007d-c4c6-4a45-b887-27d063dbe5b8',
  '1cc106b7-2158-4c58-946e-31d09472fc1d',
  '6ed8bd48-ed76-42aa-9f59-7412310352be',
  '32b234ea-90e4-4bd6-ab88-86e17cec4f2b',
  '88147c57-703e-4fb5-8cb5-f70dff2d3dd8',
  'f1cced9a-6a21-44cf-8244-bac4dec14148',
  '222306d8-50cc-4485-8816-2deb695bf630',
  'c5341fd9-f2bf-4528-ba71-7c796a0e0617',
  '573be9d7-a7a7-4194-8c47-2f39e441e389',
  'b38739cb-bad2-4b88-be1e-cd1d0ac26326',
  'abc70d74-a9ce-4133-9c99-b549af8a7adc',
  'a290903b-cb7f-4878-a7d8-a3946ca2dfac',
  '65a19668-51fe-451d-b084-2934ebecb03a',
  '89da84d7-9b3a-4af6-97bc-38a2b9dfbd18',
  'a8e7692a-7a98-43f9-8625-086c014c7526',
  'be87b197-a6f4-41b7-bbe9-42a8f9addd50',
  '03969a51-597e-4ec6-8c46-10f45c8a4727',
  'e6f34d6e-ece2-477c-aafc-e60e7015e738',
  'e331514a-b14c-4315-8bb0-387ea19c17eb',
  'ba4703be-e469-4fb3-bf9b-36b99799a95e',
  'da6dba2b-edec-4f3d-8a2f-da718107b2d9',
  'db8972a8-c0d9-4749-9c3e-3b69ce0cb230',
  'e9629aa9-6449-428d-8a1f-cc35e32ca529',
  '11edb754-ca36-4037-a7be-9bb26f0569fd',
  '69eacf9d-379e-4423-a569-675b6f8225a3',
  '14d99e95-0bf6-4b7f-9775-8fc9a11863ce',
  'bb442b7e-ed5b-41ae-81d1-9f173fb2437a',
  'd385f551-0b98-4569-97da-f92e948497f8',
  '1311d65b-0439-47a1-a2fb-8fc1aa0afb22',
  'e3d3957b-085c-443d-8e29-4864a64cb8c4',
  'e8ffcd33-2d2c-4910-af63-6714b030a2b6',
  'b14d4ff2-e70f-4dab-a2b4-cb796a9995c4',
  '0d9d56af-55fa-4feb-bcdc-2358130aaaba',
  '5aceaf9f-7eb9-4050-9480-70a9ddee615c',
  'af9c7cd0-9f8c-43e5-9eb2-dfa9a4c91c43',
  'f79b8c37-fc5b-4607-8e6c-51d4d687c971',
  'ad79bd36-6ca0-48b4-a295-66f708ac2316',
  '89406cf1-3c94-4f3f-b5a0-8167f8bcc345',
  '23728abc-6a6e-4bd2-b545-716ce3f124cf',
  '6d074d52-2cb4-43a0-9107-f0d9ac25adcd',
  '6168fd10-cb49-439d-bfac-5e4bf71b8deb',
  'ff596c74-a35c-4099-af08-35411759b0eb'
)
AND "time_zone" = 'UTC';
