import { recordAccountDeletion } from "../../datasources/users/account-deletion.datasource.js";
import { rememberDeletedAccounts } from "../../services/users/account-deletion-access.js";
import { getChatIo } from "../../realtime/chat-emitter.js";
import { publishGroupChange, publishOutingChange } from "../../realtime/data-changes.js";
import { userRealtimeRoom } from "../../realtime/rooms.js";
import { errorCode, logger } from "../../monitoring/logger.js";

export class DeleteUserUseCase {
  async execute(uid: string): Promise<void> {
    const { accountKey, groups, outings } = await recordAccountDeletion(uid);
    rememberDeletedAccounts([accountKey]);
    getChatIo()?.in(userRealtimeRoom(uid)).disconnectSockets(true);
    void Promise.all([
      ...groups.map(id => publishGroupChange(id, "membership")),
      ...outings.map(id => publishOutingChange(id)),
    ]).catch(error => logger.warn({ errorCode: errorCode(error) }, "Account deletion invalidation failed"));
  }
}
