import { tencentIMClient } from './tencent-im-client';
import { toTencentIMUserID } from './tencent-im-id';
import { tencentIMUserService } from './tencent-im-user.service';

export const tencentIMFriendService = {
  async ensureMutualFriends(userOneId: string, userTwoId: string): Promise<void> {
    await tencentIMUserService.ensureUsersByIds([userOneId, userTwoId]);

    const userOneIMId = toTencentIMUserID(userOneId);
    const userTwoIMId = toTencentIMUserID(userTwoId);

    await tencentIMClient.post('v4/sns/friend_import', {
      From_Account: userOneIMId,
      AddFriendItem: [
        {
          To_Account: userTwoIMId,
          AddSource: 'AddSource_Type_RaverMutualFollow',
        },
      ],
    });

    await tencentIMClient.post('v4/sns/friend_import', {
      From_Account: userTwoIMId,
      AddFriendItem: [
        {
          To_Account: userOneIMId,
          AddSource: 'AddSource_Type_RaverMutualFollow',
        },
      ],
    });
  },

  async sendFriendCreatedTip(userOneId: string, userTwoId: string, text: string): Promise<void> {
    await tencentIMUserService.ensureUsersByIds([userOneId, userTwoId]);

    const userOneIMId = toTencentIMUserID(userOneId);
    const userTwoIMId = toTencentIMUserID(userTwoId);

    await tencentIMClient.post('v4/openim/sendmsg', {
      SyncOtherMachine: 2,
      From_Account: userOneIMId,
      To_Account: userTwoIMId,
      MsgRandom: Math.floor(Math.random() * 0xffffffff),
      MsgBody: [
        {
          MsgType: 'TIMCustomElem',
          MsgContent: {
            Data: JSON.stringify({
              businessID: 'raver_friend_created_tip',
              version: 1,
              text,
            }),
            Desc: text,
          },
        },
      ],
    });
  },
};
