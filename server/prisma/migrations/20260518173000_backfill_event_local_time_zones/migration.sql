-- Backfill known event-local time zones from the audited multi-timezone event list.
-- Only placeholder/default values are touched so manually corrected rows are preserved.
UPDATE "events"
SET "time_zone" = CASE "id"
    WHEN 'a0fb55bf-f3b6-4c60-bc42-31634a1e3031' THEN 'Asia/Shanghai'
    WHEN '27dec11c-4217-426e-b1dc-d4ce4b1a3040' THEN 'Asia/Hong_Kong'
    WHEN 'bf015ea7-0f33-4138-849b-ca71927fa8f7' THEN 'America/Los_Angeles'
    WHEN 'e7ce7d50-7875-43f6-a9f9-cd2ea7b912cb' THEN 'America/Los_Angeles'
    WHEN '35c4e9fa-ce29-40a3-955b-06cc7f25960c' THEN 'America/New_York'
    WHEN '03f74dce-0da1-4fff-8057-48fd7571676a' THEN 'America/Mexico_City'
    WHEN '579cd698-b0fb-4e30-8c85-19fc659161a1' THEN 'America/New_York'
    WHEN '51c5fbae-e4cf-4b4e-ac1e-eb62c72ed7c3' THEN 'Asia/Hong_Kong'
    WHEN '0cea31f0-13c4-4139-9438-73337f18b82f' THEN 'Asia/Taipei'
    WHEN 'b4f0bcf0-3e6d-495a-b1a3-b2e79d616081' THEN 'America/Los_Angeles'
    WHEN '1643c00a-8405-4467-86cb-869cad67ed26' THEN 'Australia/Melbourne'
    WHEN '7f68998c-8540-46fa-a6c6-c97929e3d828' THEN 'Asia/Taipei'
    WHEN '25764286-639b-4c1f-bc43-22a4e5c62093' THEN 'America/Sao_Paulo'
    WHEN '346ade44-3df4-4368-9096-b04430c3a663' THEN 'America/Los_Angeles'
    WHEN 'ac989b06-e8c5-46ba-90cd-2ff96d113d52' THEN 'Asia/Shanghai'
    WHEN 'cf66d3f9-b6b3-4612-8592-35472474d735' THEN 'Asia/Shanghai'
    WHEN '2c36f0b3-6dbc-464e-8a6c-6aa5d78cb5fd' THEN 'Asia/Hong_Kong'
    WHEN '1ea8d6bd-a684-423f-b70a-c75f7bda64c1' THEN 'Asia/Taipei'
    WHEN '4f87de36-8a68-4b5f-82f8-c4665c162d8a' THEN 'Asia/Shanghai'
    WHEN '179ad9eb-b26d-4675-9b71-6c939a5e2635' THEN 'Asia/Shanghai'
    WHEN '73e94f95-9f30-44ff-89e2-815fa99e1ef3' THEN 'Asia/Shanghai'
    WHEN 'b10d8a5d-95eb-46a1-a924-ca1646e077e3' THEN 'America/New_York'
    WHEN '0021a9da-4c41-4f10-8729-f4fe58ad8196' THEN 'Asia/Shanghai'
    WHEN 'ec9587b3-e9c0-4ce9-9d17-2ed7516f4a4e' THEN 'Asia/Shanghai'
    WHEN 'c51e8080-c5b6-4979-b194-b66ce403fccc' THEN 'Asia/Shanghai'
    WHEN '1d46f5dc-19b4-44b7-b2e9-5ac020c4a9e5' THEN 'Asia/Shanghai'
    WHEN 'ba917417-95d0-46b2-83ee-55319335f2bf' THEN 'Asia/Shanghai'
    WHEN '0bda20c0-bfad-47d3-9fc2-73038f79644c' THEN 'America/Sao_Paulo'
    WHEN 'e7499f5c-ead0-4a51-9fe1-4638eea8828c' THEN 'Asia/Shanghai'
    WHEN '69b58914-6ec9-4955-b796-16ef4bbc633c' THEN 'Asia/Shanghai'
    WHEN 'af71c50a-c669-4454-9da2-94abc1460df3' THEN 'America/New_York'
    WHEN 'c7d032b0-fe59-4581-a2c9-dd0a336d12c1' THEN 'Asia/Shanghai'
    WHEN '72f9bf22-b795-46f1-a3ee-65b721a63542' THEN 'Asia/Taipei'
    WHEN 'a825b5cb-41e6-4fad-88cd-8b0adddd1440' THEN 'Asia/Shanghai'
    WHEN '625a66de-4217-44d2-82ba-fe6ce13bb665' THEN 'Asia/Shanghai'
    WHEN 'b6241110-ce39-4179-98d0-b54c57bd4428' THEN 'Asia/Shanghai'
    WHEN '4b62d0c3-32de-44b9-94dc-eae2a5bb38b1' THEN 'America/Mexico_City'
    WHEN '4d6c72a8-dd7a-464b-9c76-be83f392dea3' THEN 'America/New_York'
    WHEN '9eb71024-f56b-4b7f-b03f-ee5833d35414' THEN 'America/Los_Angeles'
    WHEN '37a1a4d1-3083-4c65-88c2-0647aef536a3' THEN 'Asia/Hong_Kong'
    WHEN '935a95a0-6cad-450c-be2d-a8ee58c1825e' THEN 'America/Santiago'
    WHEN 'fbfaea27-9f8b-4578-8ee5-32cfafad5de7' THEN 'Asia/Shanghai'
    WHEN '47e3ef7b-7842-41b1-85ed-797869686607' THEN 'Asia/Shanghai'
    WHEN '56711ff1-eeca-4e3a-a10c-caf249983e9e' THEN 'Asia/Shanghai'
    WHEN '28236c8b-8615-40fa-95f3-3aafda2df134' THEN 'Asia/Shanghai'
    WHEN 'e2cc377d-94ca-41cc-b9b3-2e68a6198f58' THEN 'America/Los_Angeles'
    WHEN '7aef4ad3-e88c-4c9d-8d18-a410d3c53bc1' THEN 'Asia/Hong_Kong'
    WHEN 'e09131cf-4233-46b3-8a78-8509fe32b16a' THEN 'Asia/Shanghai'
    WHEN 'a64d6481-e161-4b2d-b84d-db62b2410ad6' THEN 'Asia/Shanghai'
    WHEN 'e81b9a23-50af-42c2-80b8-59f8cf42e602' THEN 'Asia/Shanghai'
    WHEN '06d206a2-f2bf-42b6-ba15-27dba891c9c4' THEN 'Asia/Taipei'
    WHEN 'b65e4a04-47fa-49c6-8636-a23b89cf8041' THEN 'Asia/Shanghai'
    WHEN 'e99ad012-31ce-455b-aa6e-bfe80325e0e1' THEN 'America/Chicago'
    WHEN '0577afc2-a362-4e0d-8856-ab01c338ba92' THEN 'America/New_York'
    WHEN '0fb88d28-77a6-4aea-a460-9b08104f3030' THEN 'Europe/Berlin'
    WHEN '0a1f9c27-9080-414e-b410-eb7331b91964' THEN 'Asia/Hong_Kong'
    WHEN 'de5342fd-1971-42be-8bd8-7ff72147debd' THEN 'Asia/Shanghai'
    WHEN '00e0d916-4752-46b7-9136-01382a658f13' THEN 'America/New_York'
    WHEN '8b3829ba-9cb5-4dfd-a55d-5810c67ea85c' THEN 'Asia/Shanghai'
    WHEN '8dcf0293-d55d-42d9-b970-4dc13280b781' THEN 'America/Sao_Paulo'
    WHEN '787676c3-eef9-4f6a-9e4c-ae439eeb0da8' THEN 'Asia/Shanghai'
    WHEN '708421e6-ea73-49e7-ad16-ef0c5e92960a' THEN 'America/New_York'
    WHEN '5314bab6-8f7e-4935-9b5a-857215a2c7d8' THEN 'America/Santiago'
    WHEN 'f1e231b3-a05f-4517-a271-77c643305208' THEN 'Asia/Taipei'
    WHEN '4f4fc780-ea84-4723-a160-0e766ac83a0c' THEN 'Asia/Shanghai'
    WHEN 'de211007-d454-45d1-9533-f5358b191916' THEN 'Asia/Shanghai'
    WHEN '4c0bb9e7-3bb7-4693-b9cc-5617e64f52cb' THEN 'Asia/Shanghai'
    WHEN '7722342a-a654-4134-9b0f-f8a843092ca7' THEN 'Asia/Shanghai'
    WHEN '864cf724-9d02-4748-8dad-ef9c18d2b400' THEN 'America/Mexico_City'
    WHEN 'ab815bdd-08b6-44f8-a5b1-87dcc06ba166' THEN 'Asia/Hong_Kong'
    WHEN '4fe9ca34-0ba5-46dc-aca1-2fd3012b00ab' THEN 'America/Argentina/Buenos_Aires'
    WHEN '83fbef2e-0888-44df-a42e-4edb7a3dd9ce' THEN 'America/Santiago'
    WHEN '3df0d50e-3f57-4134-bd73-6769596bf426' THEN 'Asia/Shanghai'
    WHEN '2644efe7-aa26-46d5-83aa-15add4aee89e' THEN 'America/Sao_Paulo'
    WHEN '0e3e6d01-c924-4f33-b17d-ff16cc71a2c1' THEN 'America/New_York'
    WHEN '1263b7fc-353c-4806-8fc3-07db887f5ecd' THEN 'America/Los_Angeles'
    WHEN 'a02c2932-064c-49e5-8b1c-0994fed96a17' THEN 'Australia/Melbourne'
    WHEN 'ac05e890-3a2a-4197-a6cd-a0427f57729c' THEN 'America/Argentina/Buenos_Aires'
    WHEN '4a7af241-ee70-491d-9d37-900d24dd86d9' THEN 'Asia/Shanghai'
    WHEN 'aeca0fc2-7067-4d4f-89a6-15ef85d1eea5' THEN 'Asia/Shanghai'
    WHEN '21a822e1-a5bf-4a04-8936-07d6be37d73c' THEN 'America/Los_Angeles'
    WHEN 'a96ff15e-c445-408b-a88b-8c8afe9bd526' THEN 'Asia/Shanghai'
    WHEN '73857818-3434-4010-be96-e8b759629ca6' THEN 'Asia/Shanghai'
    WHEN '186f9fff-3b40-4fe2-a5ef-35e8a2835766' THEN 'Asia/Shanghai'
    WHEN '402058e5-fba7-4d60-9167-0c56f9bcb40d' THEN 'Asia/Shanghai'
    WHEN '6ef6e83c-7a2a-419e-a9c4-922594554a65' THEN 'Europe/Berlin'
    WHEN 'fcd28b27-d0c4-4bc0-9ff3-523929312a56' THEN 'Asia/Taipei'
    WHEN '8f7edd9b-ec6d-4a2c-8616-f641d541504e' THEN 'America/New_York'
    WHEN 'fce4e6cc-4bbd-48b8-9348-5423208b29d7' THEN 'America/Chicago'
    WHEN '95fc9227-f3a4-4021-857e-25e237f65db3' THEN 'Asia/Shanghai'
    WHEN '0d47f838-0b43-4ab4-9d6c-25aff6fb655c' THEN 'Asia/Shanghai'
    WHEN 'a8b831be-80d8-4a59-921f-aeed2822f992' THEN 'Europe/Madrid'
    WHEN '40c17840-830d-41fd-9f18-16b454ac77c7' THEN 'Asia/Shanghai'
    WHEN '6f43a752-4c94-4106-920c-a1847ee3bffc' THEN 'Asia/Shanghai'
    WHEN 'c530ea2c-a6b0-44c4-aaa8-29348f5f85da' THEN 'Asia/Macau'
    WHEN '8dcd4024-b51a-415b-ace5-d9a3d2a57743' THEN 'America/New_York'
    WHEN '64fd1d64-bfb6-4de0-90bd-f8eeace94bc6' THEN 'Asia/Shanghai'
    WHEN '68b621ca-5e68-4086-93f9-c30b08f13753' THEN 'America/Los_Angeles'
    WHEN '305063b2-04da-4780-a5bc-a532361b83c8' THEN 'Asia/Shanghai'
    WHEN '8c678148-83ea-445a-823c-772de667cefc' THEN 'Asia/Shanghai'
    WHEN 'b0563831-2f42-4425-b0cb-83abc52e7c86' THEN 'America/Sao_Paulo'
    WHEN '74e4e49f-ebf1-4bbe-bcca-044b09dc9d03' THEN 'America/Argentina/Buenos_Aires'
    WHEN '20c60449-35da-4b9f-8699-7590da12f3fb' THEN 'America/Santiago'
    WHEN '843266c9-a3e6-458a-993d-6131734718c9' THEN 'Asia/Shanghai'
    WHEN '35d15184-5638-451d-a7cd-2dc489a21f9e' THEN 'Asia/Shanghai'
    WHEN '0391b74b-268d-4bc0-a78b-1f114272f18e' THEN 'Asia/Shanghai'
    WHEN 'ce08d747-59d0-4018-a28b-1f73dcfdb85b' THEN 'Asia/Taipei'
    WHEN '4a397b2e-6b8e-4c13-bd2c-0b5debf9b1b0' THEN 'America/New_York'
    WHEN 'd71bc8d7-7899-4e02-baaa-615e09dc8ce2' THEN 'Asia/Shanghai'
    WHEN '0c429a51-81ed-4053-b5b6-5e7885b16ccd' THEN 'Asia/Shanghai'
    WHEN '852e662b-33c5-44ba-b429-44b12bea9251' THEN 'Asia/Shanghai'
    WHEN 'b863abbf-1174-4516-93c1-ee6f5ef36719' THEN 'Asia/Shanghai'
    WHEN '5c90e853-8825-41f3-86fe-cb5f33af5036' THEN 'Asia/Shanghai'
    WHEN '3bde1dda-35e5-4b66-be06-a017a012548b' THEN 'Asia/Shanghai'
    WHEN 'e16ae1fc-2e1c-49f1-aa30-6813fed64fa3' THEN 'Asia/Shanghai'
    WHEN '79c8c8fd-f868-4d86-b02e-44581a1df704' THEN 'America/Argentina/Buenos_Aires'
    WHEN '61ec4b26-1820-432f-96dd-106f858573dd' THEN 'America/Mexico_City'
    WHEN '89051eea-5782-4912-bc99-f279e9618f37' THEN 'Australia/Brisbane'
    WHEN '7add5c83-88b9-4fe2-b171-4072fea513e9' THEN 'Asia/Shanghai'
    WHEN '8fccd3c9-a6e0-4a58-bc7e-8b548f4dc6b0' THEN 'Asia/Shanghai'
    WHEN 'f2fcfd4a-41cb-4742-aa59-16444a9fa4f5' THEN 'America/Argentina/Buenos_Aires'
    WHEN '4677529b-6476-4264-a5a2-b975bef804d6' THEN 'America/Santiago'
    WHEN '58f0c08f-2190-4883-8160-97bb2ab562a4' THEN 'America/Sao_Paulo'
    WHEN '1056d3b9-c2e9-4b0d-8bf8-590f0e7bd60a' THEN 'Asia/Shanghai'
    WHEN 'c6594185-0d83-45fe-abf5-7013d9b2bc4c' THEN 'America/New_York'
    WHEN '693c1b53-b345-43fc-9b8f-8685822d7468' THEN 'America/Los_Angeles'
    WHEN '2029637c-e790-49ae-8aa9-1d8fbbfc1b42' THEN 'Pacific/Auckland'
    WHEN '8b20e031-649d-4266-a3c9-63ab41182e83' THEN 'Australia/Melbourne'
    WHEN '77a859c0-3ef7-4dd0-8f45-c4e103c49602' THEN 'Asia/Shanghai'
    WHEN 'f94cb82c-aea1-49ea-844c-2b7d3e0cd492' THEN 'Asia/Shanghai'
    WHEN '74e9550e-f85e-4a2f-9305-29205efd4652' THEN 'Asia/Shanghai'
    WHEN '981b09d7-e8b3-417e-a5d5-6a4c4a70c076' THEN 'Asia/Shanghai'
    WHEN '2acc36a2-3fb0-46e9-a2d8-e40441a6f236' THEN 'America/Los_Angeles'
    WHEN '4fc5b89c-60e0-485d-a73a-04e0f472c962' THEN 'Asia/Taipei'
    WHEN '75be0883-3f11-4651-b11d-90ae07d93481' THEN 'Europe/Berlin'
    WHEN 'a7fcf183-cc21-4b2a-90ea-17fdfaa90e3e' THEN 'America/Chicago'
    ELSE "time_zone"
END
WHERE "id" IN (
    'a0fb55bf-f3b6-4c60-bc42-31634a1e3031',
    '27dec11c-4217-426e-b1dc-d4ce4b1a3040',
    'bf015ea7-0f33-4138-849b-ca71927fa8f7',
    'e7ce7d50-7875-43f6-a9f9-cd2ea7b912cb',
    '35c4e9fa-ce29-40a3-955b-06cc7f25960c',
    '03f74dce-0da1-4fff-8057-48fd7571676a',
    '579cd698-b0fb-4e30-8c85-19fc659161a1',
    '51c5fbae-e4cf-4b4e-ac1e-eb62c72ed7c3',
    '0cea31f0-13c4-4139-9438-73337f18b82f',
    'b4f0bcf0-3e6d-495a-b1a3-b2e79d616081',
    '1643c00a-8405-4467-86cb-869cad67ed26',
    '7f68998c-8540-46fa-a6c6-c97929e3d828',
    '25764286-639b-4c1f-bc43-22a4e5c62093',
    '346ade44-3df4-4368-9096-b04430c3a663',
    'ac989b06-e8c5-46ba-90cd-2ff96d113d52',
    'cf66d3f9-b6b3-4612-8592-35472474d735',
    '2c36f0b3-6dbc-464e-8a6c-6aa5d78cb5fd',
    '1ea8d6bd-a684-423f-b70a-c75f7bda64c1',
    '4f87de36-8a68-4b5f-82f8-c4665c162d8a',
    '179ad9eb-b26d-4675-9b71-6c939a5e2635',
    '73e94f95-9f30-44ff-89e2-815fa99e1ef3',
    'b10d8a5d-95eb-46a1-a924-ca1646e077e3',
    '0021a9da-4c41-4f10-8729-f4fe58ad8196',
    'ec9587b3-e9c0-4ce9-9d17-2ed7516f4a4e',
    'c51e8080-c5b6-4979-b194-b66ce403fccc',
    '1d46f5dc-19b4-44b7-b2e9-5ac020c4a9e5',
    'ba917417-95d0-46b2-83ee-55319335f2bf',
    '0bda20c0-bfad-47d3-9fc2-73038f79644c',
    'e7499f5c-ead0-4a51-9fe1-4638eea8828c',
    '69b58914-6ec9-4955-b796-16ef4bbc633c',
    'af71c50a-c669-4454-9da2-94abc1460df3',
    'c7d032b0-fe59-4581-a2c9-dd0a336d12c1',
    '72f9bf22-b795-46f1-a3ee-65b721a63542',
    'a825b5cb-41e6-4fad-88cd-8b0adddd1440',
    '625a66de-4217-44d2-82ba-fe6ce13bb665',
    'b6241110-ce39-4179-98d0-b54c57bd4428',
    '4b62d0c3-32de-44b9-94dc-eae2a5bb38b1',
    '4d6c72a8-dd7a-464b-9c76-be83f392dea3',
    '9eb71024-f56b-4b7f-b03f-ee5833d35414',
    '37a1a4d1-3083-4c65-88c2-0647aef536a3',
    '935a95a0-6cad-450c-be2d-a8ee58c1825e',
    'fbfaea27-9f8b-4578-8ee5-32cfafad5de7',
    '47e3ef7b-7842-41b1-85ed-797869686607',
    '56711ff1-eeca-4e3a-a10c-caf249983e9e',
    '28236c8b-8615-40fa-95f3-3aafda2df134',
    'e2cc377d-94ca-41cc-b9b3-2e68a6198f58',
    '7aef4ad3-e88c-4c9d-8d18-a410d3c53bc1',
    'e09131cf-4233-46b3-8a78-8509fe32b16a',
    'a64d6481-e161-4b2d-b84d-db62b2410ad6',
    'e81b9a23-50af-42c2-80b8-59f8cf42e602',
    '06d206a2-f2bf-42b6-ba15-27dba891c9c4',
    'b65e4a04-47fa-49c6-8636-a23b89cf8041',
    'e99ad012-31ce-455b-aa6e-bfe80325e0e1',
    '0577afc2-a362-4e0d-8856-ab01c338ba92',
    '0fb88d28-77a6-4aea-a460-9b08104f3030',
    '0a1f9c27-9080-414e-b410-eb7331b91964',
    'de5342fd-1971-42be-8bd8-7ff72147debd',
    '00e0d916-4752-46b7-9136-01382a658f13',
    '8b3829ba-9cb5-4dfd-a55d-5810c67ea85c',
    '8dcf0293-d55d-42d9-b970-4dc13280b781',
    '787676c3-eef9-4f6a-9e4c-ae439eeb0da8',
    '708421e6-ea73-49e7-ad16-ef0c5e92960a',
    '5314bab6-8f7e-4935-9b5a-857215a2c7d8',
    'f1e231b3-a05f-4517-a271-77c643305208',
    '4f4fc780-ea84-4723-a160-0e766ac83a0c',
    'de211007-d454-45d1-9533-f5358b191916',
    '4c0bb9e7-3bb7-4693-b9cc-5617e64f52cb',
    '7722342a-a654-4134-9b0f-f8a843092ca7',
    '864cf724-9d02-4748-8dad-ef9c18d2b400',
    'ab815bdd-08b6-44f8-a5b1-87dcc06ba166',
    '4fe9ca34-0ba5-46dc-aca1-2fd3012b00ab',
    '83fbef2e-0888-44df-a42e-4edb7a3dd9ce',
    '3df0d50e-3f57-4134-bd73-6769596bf426',
    '2644efe7-aa26-46d5-83aa-15add4aee89e',
    '0e3e6d01-c924-4f33-b17d-ff16cc71a2c1',
    '1263b7fc-353c-4806-8fc3-07db887f5ecd',
    'a02c2932-064c-49e5-8b1c-0994fed96a17',
    'ac05e890-3a2a-4197-a6cd-a0427f57729c',
    '4a7af241-ee70-491d-9d37-900d24dd86d9',
    'aeca0fc2-7067-4d4f-89a6-15ef85d1eea5',
    '21a822e1-a5bf-4a04-8936-07d6be37d73c',
    'a96ff15e-c445-408b-a88b-8c8afe9bd526',
    '73857818-3434-4010-be96-e8b759629ca6',
    '186f9fff-3b40-4fe2-a5ef-35e8a2835766',
    '402058e5-fba7-4d60-9167-0c56f9bcb40d',
    '6ef6e83c-7a2a-419e-a9c4-922594554a65',
    'fcd28b27-d0c4-4bc0-9ff3-523929312a56',
    '8f7edd9b-ec6d-4a2c-8616-f641d541504e',
    'fce4e6cc-4bbd-48b8-9348-5423208b29d7',
    '95fc9227-f3a4-4021-857e-25e237f65db3',
    '0d47f838-0b43-4ab4-9d6c-25aff6fb655c',
    'a8b831be-80d8-4a59-921f-aeed2822f992',
    '40c17840-830d-41fd-9f18-16b454ac77c7',
    '6f43a752-4c94-4106-920c-a1847ee3bffc',
    'c530ea2c-a6b0-44c4-aaa8-29348f5f85da',
    '8dcd4024-b51a-415b-ace5-d9a3d2a57743',
    '64fd1d64-bfb6-4de0-90bd-f8eeace94bc6',
    '68b621ca-5e68-4086-93f9-c30b08f13753',
    '305063b2-04da-4780-a5bc-a532361b83c8',
    '8c678148-83ea-445a-823c-772de667cefc',
    'b0563831-2f42-4425-b0cb-83abc52e7c86',
    '74e4e49f-ebf1-4bbe-bcca-044b09dc9d03',
    '20c60449-35da-4b9f-8699-7590da12f3fb',
    '843266c9-a3e6-458a-993d-6131734718c9',
    '35d15184-5638-451d-a7cd-2dc489a21f9e',
    '0391b74b-268d-4bc0-a78b-1f114272f18e',
    'ce08d747-59d0-4018-a28b-1f73dcfdb85b',
    '4a397b2e-6b8e-4c13-bd2c-0b5debf9b1b0',
    'd71bc8d7-7899-4e02-baaa-615e09dc8ce2',
    '0c429a51-81ed-4053-b5b6-5e7885b16ccd',
    '852e662b-33c5-44ba-b429-44b12bea9251',
    'b863abbf-1174-4516-93c1-ee6f5ef36719',
    '5c90e853-8825-41f3-86fe-cb5f33af5036',
    '3bde1dda-35e5-4b66-be06-a017a012548b',
    'e16ae1fc-2e1c-49f1-aa30-6813fed64fa3',
    '79c8c8fd-f868-4d86-b02e-44581a1df704',
    '61ec4b26-1820-432f-96dd-106f858573dd',
    '89051eea-5782-4912-bc99-f279e9618f37',
    '7add5c83-88b9-4fe2-b171-4072fea513e9',
    '8fccd3c9-a6e0-4a58-bc7e-8b548f4dc6b0',
    'f2fcfd4a-41cb-4742-aa59-16444a9fa4f5',
    '4677529b-6476-4264-a5a2-b975bef804d6',
    '58f0c08f-2190-4883-8160-97bb2ab562a4',
    '1056d3b9-c2e9-4b0d-8bf8-590f0e7bd60a',
    'c6594185-0d83-45fe-abf5-7013d9b2bc4c',
    '693c1b53-b345-43fc-9b8f-8685822d7468',
    '2029637c-e790-49ae-8aa9-1d8fbbfc1b42',
    '8b20e031-649d-4266-a3c9-63ab41182e83',
    '77a859c0-3ef7-4dd0-8f45-c4e103c49602',
    'f94cb82c-aea1-49ea-844c-2b7d3e0cd492',
    '74e9550e-f85e-4a2f-9305-29205efd4652',
    '981b09d7-e8b3-417e-a5d5-6a4c4a70c076',
    '2acc36a2-3fb0-46e9-a2d8-e40441a6f236',
    '4fc5b89c-60e0-485d-a73a-04e0f472c962',
    '75be0883-3f11-4651-b11d-90ae07d93481',
    'a7fcf183-cc21-4b2a-90ea-17fdfaa90e3e'
)
AND "time_zone" IN ('UTC', 'Etc/UTC', 'GMT', 'GMT+00:00', 'GMT-00:00', 'Asia/Shanghai');
