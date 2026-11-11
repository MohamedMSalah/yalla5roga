import 'dotenv/config';
import { prisma } from '../src/config/database.js';
import { getFirebaseAuth } from '../src/config/firebase.js';
import { tryNormalizePhoneNumber } from '../src/services/phone/normalize-phone.js';
try {
  const result = await prisma.$queryRaw`SELECT (SELECT count(*)::int FROM users) AS users, (SELECT count(*)::int FROM group_members) AS memberships, (SELECT count(*)::int FROM group_invitations WHERE status='pending') AS pending, (SELECT count(*)::int FROM group_invitations i JOIN users u ON u.phone=i.invited_phone WHERE i.status='pending') AS pending_for_registered_users, (SELECT count(*)::int FROM group_members m LEFT JOIN users u ON u.id=m.user_id LEFT JOIN groups g ON g.id=m.group_id WHERE u.id IS NULL OR g.id IS NULL) AS orphan_memberships`;
  const rows = await prisma.group_invitations.findMany({where:{status:'pending'}, select:{invited_phone:true}});
  const counts = {registeredRecipients:0, splitFirebaseIdentities:0, verifiedCanonicalIdentities:0, canonicalMissingPhone:0, nonCanonicalPhoneFormats:0};
  for (const phone of new Set(rows.map(r=>r.invited_phone))) {
    if (tryNormalizePhoneNumber(phone)!==phone) counts.nonCanonicalPhoneFormats++;
    const local = await prisma.users.findUnique({where:{phone},select:{id:true}});
    if (!local) continue;
    counts.registeredRecipients++;
    const canonical = await getFirebaseAuth().getUser(local.id);
    if (!canonical.phoneNumber) counts.canonicalMissingPhone++;
    if (canonical.phoneNumber===phone) counts.verifiedCanonicalIdentities++;
    try {
      const verified = await getFirebaseAuth().getUserByPhoneNumber(phone);
      if (verified.uid!==local.id) counts.splitFirebaseIdentities++;
    } catch (error) {if ((error as {code?:string}).code!=='auth/user-not-found') throw error;}
  }
  console.log(JSON.stringify({database:result,identityAudit:counts}));
} finally {await prisma.$disconnect();}
