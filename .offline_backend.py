exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
p=Path('backend/src/controllers/groups/group.controller.ts'); s=p.read_text(encoding='utf-8')
s='import { emitDataChange, groupRealtimeUsers, publishGroupChange } from "../../realtime/data-changes.js";\n'+s
def before(start, target, line):
 global s
 i=s.index(target,s.index(start))
 s=s[:i]+line+s[i:]
before('  create =','      res.status(201)', '      emitDataChange({ kind: "group", id: group.id }, [req.user.uid]);\n')
before('  update =','      res.json', '      await publishGroupChange(group.id, "group");\n')
before('  remove =','      const group =','      const audience = await groupRealtimeUsers(req.params.id as string);\n')
before('  remove =','      res.json','      emitDataChange({ kind: "membership", id: group.id }, audience);\n')
before('  addGroupMember =','      res.status(201)','      await publishGroupChange(req.params.id as string, "membership");\n')
before('  invite =','        return res.status(201)','        await publishGroupChange(req.params.id as string, "membership");\n')
before('      if (result.outcome === "invited")','        return res.status(201)','        await publishGroupChange(req.params.id as string, "group");\n')
before('  revokePendingMembership =','      res.json','      await publishGroupChange(req.params.id as string, "group");\n')
before('  removeGroupMember =','      res.json','      await publishGroupChange(req.params.id as string, "membership", [req.params.userId as string]);\n')
p.write_text(s,encoding='utf-8')
p=Path('backend/src/controllers/outings/outing.controller.ts'); s=p.read_text(encoding='utf-8')
s='import { emitDataChange, outingRealtimeUsers, publishOutingChange } from "../../realtime/data-changes.js";\n'+s
before('  create =','      res.status(201)','      await publishOutingChange(outing.id, "outings");\n')
before('  update =','      const outing =','      const audience = req.body.group_id !== undefined\n        ? await outingRealtimeUsers(req.params.id as string) : [];\n')
before('  update =','      res.json','      await publishOutingChange(outing.id, "outings", audience);\n')
before('  remove =','      const outing =','      const audience = await outingRealtimeUsers(req.params.id as string);\n')
before('  remove =','      res.json','      emitDataChange({ kind: "outings", id: outing.id }, audience);\n')
for method in ('setAttendance', 'addVoteOption', 'replaceOptions', 'removeVoteOption', 'vote', 'unvote', 'breakTie', 'confirmVenue', 'cancel'):
 start=s.index('  '+method+' =')
 end=s.index('    } catch',start)
 i=s.rindex('      res.',start,end)
 s=s[:i]+f'      await publishOutingChange(req.params.id as string);\n'+s[i:]
for method, extra in (('inviteGuest',''),('uninviteGuest',', [req.params.userId as string]'),('acceptInvite',''),('declineInvite',', [req.user.uid]')):
 start=s.index('  '+method+' =')
 end=s.index('    } catch',start)
 i=s.rindex('      res.',start,end)
 s=s[:i]+f'      await publishOutingChange(req.params.id as string, "outings"{extra});\n'+s[i:]
p.write_text(s,encoding='utf-8')
edit('backend/src/usecases/groups/claim-group-invitations.usecase.ts',
 ('export class ClaimGroupInvitationsUseCase', 'import { publishGroupChange } from "../../realtime/data-changes.js";\n\nexport class ClaimGroupInvitationsUseCase'),
 ('    return this.invitations.claimForVerifiedPhone(input.userId, phone);','''    const claimed = await this.invitations.claimForVerifiedPhone(input.userId, phone);
    await Promise.all(claimed.map(({ group_id }) =>
      publishGroupChange(group_id, "membership", [input.userId]),
    ));
    return claimed;'''))
edit('backend/src/controllers/users/user.controller.ts',
 ('export class UserController','import { emitDataChange, publishGroupChange } from "../../realtime/data-changes.js";\nimport { prisma } from "../../config/database.js";\nimport { getChatIo } from "../../realtime/chat-emitter.js";\n\nexport class UserController'),
 ('      const user = await this.updateUser.execute(req.user.uid, req.body);','''      const user = await this.updateUser.execute(req.user.uid, req.body);
      emitDataChange({ kind: "profile" }, [req.user.uid]);
      if (getChatIo()) {
        void prisma.group_members.findMany({
          where: { user_id: req.user.uid },
          select: { group_id: true },
        }).then((groups) => Promise.all(groups.map(({ group_id }) =>
          publishGroupChange(group_id, "group"),
        ))).catch((error: unknown) => console.error("[realtime] profile audience", error));
      }'''))
edit('backend/src/usecases/chat/send-message.usecase.ts',
 ('export class SendMessageUseCase','import { emitDataChange, outingRealtimeUsers } from "../../realtime/data-changes.js";\n\nexport class SendMessageUseCase'),
 ('    emitOutingMessage(input.outing_id, message);','''    const audience = await outingRealtimeUsers(input.outing_id);
    await emitOutingMessage(input.outing_id, message, audience);'''),
 ('    return message;','    emitDataChange({ kind: "inbox" }, audience.filter((id) => id !== input.sender_id));\n    return message;'))
edit('backend/src/realtime/chat-emitter.ts',
 ('''export function emitOutingMessage(outingId: string, message: ChatMessage): void {
  if (!io) return;
  io.to(outingChatRoom(outingId)).emit(
    "outing:message",
    serializeChatMessage(message),
  );
}''','''export async function emitOutingMessage(
  outingId: string, message: ChatMessage, audience: readonly string[],
): Promise<void> {
  if (!io || audience.length === 0) return;
  const authorized = new Set(audience);
  // Room membership can outlive a removed group/outing membership.
  const sockets = await io.in(outingChatRoom(outingId)).fetchSockets();
  const recipients = sockets.filter((socket) => authorized.has(socket.data.uid));
  for (const socket of recipients) socket.emit("outing:message", serializeChatMessage(message));
}'''))
