import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/outings/domain/entities/group_place_suggestion.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';

/// All mock seed data and in-memory mutable state for Mock Data Mode.
///
/// Keep every demo fixture here so the temporary mock layer is easy to delete.
class MockData {
  MockData._();

  static const String defaultCoverImage =
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800';

  static const String birthdayCover =
      'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?w=800';

  static const String weddingCover =
      'https://images.unsplash.com/photo-1519741497674-611481863552?w=800';

  // ─── Auth ───────────────────────────────────────────────────────────────

  static User currentUser = const User(
    id: 'u_sara',
    name: 'Sara Hassan',
    phone: '+201012345678',
    email: 'sara.hassan@gmail.com',
    token: 'mock-demo-token',
    imageUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
  );

  static bool sessionActive = true;

  // ─── People ─────────────────────────────────────────────────────────────

  static final GroupMember me = GroupMember(
    id: currentUser.id,
    name: currentUser.name,
    avatar: currentUser.imageUrl ?? '',
    role: GroupRole.owner,
    phone: currentUser.phone,
  );

  static const GroupMember omar = GroupMember(
    id: 'u_omar',
    name: 'Omar Farouk',
    avatar:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    role: GroupRole.member,
    phone: '+201098765432',
  );

  static const GroupMember nadia = GroupMember(
    id: 'u_nadia',
    name: 'Nadia Elmasry',
    avatar:
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
    role: GroupRole.member,
    phone: '+201055512345',
  );

  static const GroupMember karim = GroupMember(
    id: 'u_karim',
    name: 'Karim Nabil',
    avatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
    role: GroupRole.member,
    phone: '+201022233344',
  );

  static const GroupMember layla = GroupMember(
    id: 'u_layla',
    name: 'Layla Mansour',
    avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
    role: GroupRole.member,
    phone: '+201077788899',
  );

  static const GroupMember youssef = GroupMember(
    id: 'u_youssef',
    name: 'Youssef Adel',
    avatar:
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200',
    role: GroupRole.member,
    phone: '+201033344455',
  );

  static const GroupMember mona = GroupMember(
    id: 'u_mona',
    name: 'Mona Khalil',
    avatar:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
    role: GroupRole.member,
    phone: '+201066677788',
  );

  static const GroupMember hassan = GroupMember(
    id: 'u_hassan',
    name: 'Hassan Ibrahim',
    avatar:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200',
    role: GroupRole.member,
    phone: '+201044455566',
  );

  static List<GroupMember> get allMembers => [
    me.copyWith(role: GroupRole.owner),
    omar,
    nadia,
    karim,
    layla,
    youssef,
    mona,
    hassan,
  ];

  static List<GroupMember> get contacts =>
      allMembers.where((m) => m.id != currentUser.id).toList(growable: false);

  // ─── Places (catalog + discover) — fictional demo venues only ───────────

  static final List<Place> catalogPlaces = [
    const Place(
      id: 'p_lotus',
      name: 'Lotus Kitchen',
      area: 'Palm District',
      latitude: 30.1101,
      longitude: 31.3101,
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800',
      vibe: OutingVibe.food,
    ),
    const Place(
      id: 'p_riverview',
      name: 'Riverview Table',
      area: 'Palm District',
      latitude: 30.1115,
      longitude: 31.3118,
      imageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
      vibe: OutingVibe.food,
    ),
    const Place(
      id: 'p_brew',
      name: 'Copper Brew Café',
      area: 'Maple Heights',
      latitude: 29.9902,
      longitude: 31.2901,
      imageUrl:
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
      vibe: OutingVibe.food,
    ),
    const Place(
      id: 'p_starlight',
      name: 'Starlight Cinema',
      area: 'East Plaza',
      latitude: 30.0405,
      longitude: 31.5202,
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
      vibe: OutingVibe.movie,
    ),
    const Place(
      id: 'p_neon',
      name: 'Neon Screen House',
      area: 'West Arcade',
      latitude: 29.9801,
      longitude: 30.9601,
      imageUrl:
          'https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=800',
      vibe: OutingVibe.movie,
    ),
    const Place(
      id: 'p_rally',
      name: 'Rally Court Club',
      area: 'Green Belt',
      latitude: 30.0701,
      longitude: 30.9901,
      imageUrl:
          'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=800',
      vibe: OutingVibe.activity,
    ),
    const Place(
      id: 'p_peak',
      name: 'Peak Indoor Walls',
      area: 'North Hub',
      latitude: 30.0901,
      longitude: 31.3601,
      imageUrl:
          'https://images.unsplash.com/photo-1522163182402-834f871fd851?w=800',
      vibe: OutingVibe.activity,
    ),
    const Place(
      id: 'p_olive',
      name: 'Olive Grove Gardens',
      area: 'Old Quarter',
      latitude: 30.0551,
      longitude: 31.2751,
      imageUrl:
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      vibe: OutingVibe.outdoor,
    ),
    const Place(
      id: 'p_sail',
      name: 'Sunset Sail Pier',
      area: 'Riverfront',
      latitude: 30.0521,
      longitude: 31.2411,
      imageUrl:
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800',
      vibe: OutingVibe.outdoor,
    ),
    const Place(
      id: 'p_dawn',
      name: 'Dawn Roast Café',
      area: 'Sunrise Avenue',
      latitude: 30.1001,
      longitude: 31.3401,
      imageUrl:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
      vibe: OutingVibe.food,
    ),
  ];

  static List<SuggestedPlace> suggestedPlaces = [
    SuggestedPlace(
      id: 'p_lotus',
      name: 'Lotus Kitchen',
      area: 'Palm District',
      vibe: OutingVibe.food,
      coverImageUrl: catalogPlaces[0].imageUrl,
      description: 'Demo street-food kitchen with shared tables — great for a casual group dinner.',
      priceLevel: PriceLevel.moderate,
      priceMin: 180,
      priceMax: 350,
      latitude: 30.1101,
      longitude: 31.3101,
      featured: true,
      images: [
        DiscoverPlaceImage(imageUrl: catalogPlaces[0].imageUrl),
        const DiscoverPlaceImage(
          imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae83?w=800',
        ),
      ],
      hours: const [
        DiscoverPlaceHours(
          day: Weekday.friday,
          opensAt: '12:00',
          closesAt: '01:00',
        ),
        DiscoverPlaceHours(
          day: Weekday.saturday,
          opensAt: '12:00',
          closesAt: '01:00',
        ),
      ],
      prices: const [
        DiscoverPlacePrice(labelKey: 'mains', amount: 220),
        DiscoverPlacePrice(labelKey: 'drinks', amount: 60),
      ],
    ),
    SuggestedPlace(
      id: 'p_riverview',
      name: 'Riverview Table',
      area: 'Palm District',
      vibe: OutingVibe.food,
      coverImageUrl: catalogPlaces[1].imageUrl,
      description: 'Fictional brunch spot with shared plates and soft music.',
      priceLevel: PriceLevel.expensive,
      priceMin: 250,
      priceMax: 500,
      latitude: 30.1115,
      longitude: 31.3118,
      featured: true,
    ),
    SuggestedPlace(
      id: 'p_brew',
      name: 'Copper Brew Café',
      area: 'Maple Heights',
      vibe: OutingVibe.food,
      coverImageUrl: catalogPlaces[2].imageUrl,
      description: 'Made-up café for coffee meet-ups with outdoor seating.',
      priceLevel: PriceLevel.budget,
      priceMin: 80,
      priceMax: 160,
      latitude: 29.9902,
      longitude: 31.2901,
    ),
    SuggestedPlace(
      id: 'p_starlight',
      name: 'Starlight Cinema',
      area: 'East Plaza',
      vibe: OutingVibe.movie,
      coverImageUrl: catalogPlaces[3].imageUrl,
      description: 'Demo cinema with nearby spots for after the film.',
      priceLevel: PriceLevel.moderate,
      priceMin: 120,
      priceMax: 200,
      latitude: 30.0405,
      longitude: 31.5202,
      featured: true,
    ),
    SuggestedPlace(
      id: 'p_neon',
      name: 'Neon Screen House',
      area: 'West Arcade',
      vibe: OutingVibe.movie,
      coverImageUrl: catalogPlaces[4].imageUrl,
      description: 'Fictional big-screen venue next to a food court.',
      priceLevel: PriceLevel.moderate,
      priceMin: 140,
      priceMax: 250,
      latitude: 29.9801,
      longitude: 30.9601,
    ),
    SuggestedPlace(
      id: 'p_rally',
      name: 'Rally Court Club',
      area: 'Green Belt',
      vibe: OutingVibe.activity,
      coverImageUrl: catalogPlaces[5].imageUrl,
      description: 'Demo padél courts with smoothies after the match.',
      priceLevel: PriceLevel.moderate,
      priceMin: 200,
      priceMax: 400,
      latitude: 30.0701,
      longitude: 30.9901,
      featured: true,
    ),
    SuggestedPlace(
      id: 'p_peak',
      name: 'Peak Indoor Walls',
      area: 'North Hub',
      vibe: OutingVibe.activity,
      coverImageUrl: catalogPlaces[6].imageUrl,
      description: 'Fictional indoor climbing hall for beginners and regulars.',
      priceLevel: PriceLevel.budget,
      priceMin: 150,
      priceMax: 250,
      latitude: 30.0901,
      longitude: 31.3601,
    ),
    SuggestedPlace(
      id: 'p_olive',
      name: 'Olive Grove Gardens',
      area: 'Old Quarter',
      vibe: OutingVibe.outdoor,
      coverImageUrl: catalogPlaces[7].imageUrl,
      description: 'Demo park for sunset walks and picnic blankets.',
      priceLevel: PriceLevel.budget,
      priceMin: 20,
      priceMax: 80,
      latitude: 30.0551,
      longitude: 31.2751,
      featured: true,
    ),
    SuggestedPlace(
      id: 'p_sail',
      name: 'Sunset Sail Pier',
      area: 'Riverfront',
      vibe: OutingVibe.outdoor,
      coverImageUrl: catalogPlaces[8].imageUrl,
      description: 'Made-up pier outing — bring snacks and a playlist.',
      priceLevel: PriceLevel.budget,
      priceMin: 100,
      priceMax: 250,
      latitude: 30.0521,
      longitude: 31.2411,
    ),
    SuggestedPlace(
      id: 'p_dawn',
      name: 'Dawn Roast Café',
      area: 'Sunrise Avenue',
      vibe: OutingVibe.food,
      coverImageUrl: catalogPlaces[9].imageUrl,
      description:
          'Fictional all-day café with breakfast boards and cold brew.',
      priceLevel: PriceLevel.moderate,
      priceMin: 120,
      priceMax: 280,
      latitude: 30.1001,
      longitude: 31.3401,
    ),
  ];

  // ─── Groups ─────────────────────────────────────────────────────────────

  static List<Group> groups = [
    Group(
      id: 'g_weekend',
      name: 'Weekend Squad',
      outings: 2,
      bio: 'Weekend plans, food runs, and spontaneous hangouts.',
      image:
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800',
      members: [
        me.copyWith(role: GroupRole.owner),
        omar,
        nadia,
        karim,
        youssef,
      ],
      cuserRole: GroupRole.owner,
    ),
    Group(
      id: 'g_foodies',
      name: 'Palm Foodies',
      outings: 1,
      bio: 'Chasing the best plates around New Cairo.',
      image:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      members: [
        me.copyWith(role: GroupRole.member),
        layla.copyWith(role: GroupRole.owner),
        mona,
        hassan,
      ],
      cuserRole: GroupRole.member,
    ),
    Group(
      id: 'g_cinema',
      name: 'Cinema Club',
      outings: 1,
      bio: 'Movies first, snacks always.',
      image:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
      members: [
        me.copyWith(role: GroupRole.member),
        karim.copyWith(role: GroupRole.owner),
        nadia,
        omar,
      ],
      cuserRole: GroupRole.member,
    ),
    Group(
      id: 'g_outdoors',
      name: 'River Outdoors',
      outings: 1,
      bio: 'Walks, sails, and fresh air by the Nile.',
      image:
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      members: [
        me.copyWith(role: GroupRole.owner),
        youssef,
        layla.copyWith(role: GroupRole.member),
      ],
      cuserRole: GroupRole.owner,
    ),
  ];

  // ─── Outings ────────────────────────────────────────────────────────────

  static final DateTime _now = DateTime.now();

  static List<Outing> outings = [
    Outing(
      id: 'o_padel_vote',
      image: catalogPlaces[5].imageUrl,
      title: 'Saturday Padél ',
      meta: 'Green Belt · Voting',
      date: _fmtDate(_now.add(const Duration(days: 2))),
      time: '5:00 PM',
      going: 2,
      groupId: 'g_weekend',
      status: OutingStatus.voting,
      votePlaces: [catalogPlaces[5], catalogPlaces[6]],
      voteDeadlineHours: 24,
      suggestedBy: 'Omar Farouk',
      scheduledAt: _now.add(const Duration(days: 2, hours: 17)),
      createdById: omar.id,
    ),
    Outing(
      id: 'o_zooba',
      image: catalogPlaces[0].imageUrl,
      title: 'Thursday Dinner at Lotus Kitchen',
      meta: 'Palm District · 8:00 PM',
      date: _fmtDate(_now.add(const Duration(days: 1))),
      time: '8:00 PM',
      going: 3,
      groupId: 'g_foodies',
      location: const PlaceLocation(
        name: 'Lotus Kitchen',
        area: 'Palm District',
        latitude: 30.1101,
        longitude: 31.3101,
      ),
      status: OutingStatus.upcoming,
      scheduledAt: _now.add(const Duration(days: 1, hours: 20)),
      createdById: currentUser.id,
    ),
    Outing(
      id: 'o_cinema_vote',
      image: catalogPlaces[3].imageUrl,
      title: 'Friday Night Movie',
      meta: 'East Plaza · Voting',
      date: _fmtDate(_now.add(const Duration(days: 3))),
      time: '9:30 PM',
      going: 1,
      groupId: 'g_cinema',
      status: OutingStatus.voting,
      votePlaces: [catalogPlaces[3], catalogPlaces[4]],
      voteDeadlineHours: 48,
      suggestedBy: 'Karim Nabil',
      scheduledAt: _now.add(const Duration(days: 3, hours: 21, minutes: 30)),
      createdById: karim.id,
    ),
    Outing(
      id: 'o_felucca_past',
      image: catalogPlaces[8].imageUrl,
      title: 'Sunset Sail Evening',
      meta: 'Riverfront · Completed',
      date: _fmtDate(_now.subtract(const Duration(days: 5))),
      time: '6:30 PM',
      going: 3,
      groupId: 'g_outdoors',
      location: const PlaceLocation(
        name: 'Sunset Sail Pier',
        area: 'Riverfront',
        latitude: 30.0521,
        longitude: 31.2411,
      ),
      status: OutingStatus.past,
      scheduledAt: _now.subtract(const Duration(days: 5, hours: 6)),
      createdById: currentUser.id,
    ),
    Outing(
      id: 'o_brunch',
      image: catalogPlaces[1].imageUrl,
      title: 'Sunday Brunch at Riverview Table',
      meta: 'Palm District · 12:00 PM',
      date: _fmtDate(_now.add(const Duration(days: 5))),
      time: '12:00 PM',
      going: 4,
      groupId: 'g_weekend',
      location: const PlaceLocation(
        name: 'Riverview Table',
        area: 'Palm District',
        latitude: 30.1115,
        longitude: 31.3118,
      ),
      status: OutingStatus.upcoming,
      scheduledAt: _now.add(const Duration(days: 5, hours: 12)),
      createdById: nadia.id,
    ),
  ];

  static List<GroupPlaceSuggestion> suggestions = [
    GroupPlaceSuggestion(
      id: 's_padel',
      groupId: 'g_weekend',
      title: 'Saturday Padél ',
      places: [catalogPlaces[5], catalogPlaces[6]],
      deadlineHours: 24,
      createdBy: 'Omar Farouk',
      outingId: 'o_padel_vote',
    ),
    GroupPlaceSuggestion(
      id: 's_cinema',
      groupId: 'g_cinema',
      title: 'Friday Night Movie',
      places: [catalogPlaces[3], catalogPlaces[4]],
      deadlineHours: 48,
      createdBy: 'Karim Nabil',
      outingId: 'o_cinema_vote',
    ),
  ];

  static Map<String, PlaceVote> votesByOuting = {
    'o_padel_vote': PlaceVote(
      outingId: 'o_padel_vote',
      options: const [
        VoteOption('p_rally', 'Rally Court Club', 2, 67),
        VoteOption('p_peak', 'Peak Indoor Walls', 1, 33),
      ],
      endsAt: _now.add(const Duration(hours: 18)),
      suggestedById: omar.id,
    ),
    'o_cinema_vote': PlaceVote(
      outingId: 'o_cinema_vote',
      options: const [
        VoteOption('p_starlight', 'Starlight Cinema', 1, 50),
        VoteOption('p_neon', 'Neon Screen House', 1, 50),
      ],
      endsAt: _now.add(const Duration(hours: 40)),
      cuserOptionIds: const ['p_starlight'],
      suggestedById: karim.id,
      finalized: true,
    ),
  };

  static Map<String, Map<String, AttendanceStatus>> attendanceByOuting = {
    'o_padel_vote': {
      currentUser.id: AttendanceStatus.notVoted,
      omar.id: AttendanceStatus.going,
      nadia.id: AttendanceStatus.going,
      karim.id: AttendanceStatus.notGoing,
      youssef.id: AttendanceStatus.notVoted,
    },
    'o_zooba': {
      currentUser.id: AttendanceStatus.going,
      layla.id: AttendanceStatus.going,
      mona.id: AttendanceStatus.going,
      hassan.id: AttendanceStatus.notGoing,
    },
    'o_cinema_vote': {
      currentUser.id: AttendanceStatus.going,
      karim.id: AttendanceStatus.going,
      nadia.id: AttendanceStatus.notVoted,
      omar.id: AttendanceStatus.notVoted,
    },
    'o_felucca_past': {
      currentUser.id: AttendanceStatus.going,
      youssef.id: AttendanceStatus.going,
      layla.id: AttendanceStatus.going,
    },
    'o_brunch': {
      currentUser.id: AttendanceStatus.going,
      omar.id: AttendanceStatus.going,
      nadia.id: AttendanceStatus.going,
      karim.id: AttendanceStatus.going,
      youssef.id: AttendanceStatus.notGoing,
    },
  };

  // ─── Notifications ──────────────────────────────────────────────────────

  static List<NotificationItem> notifications = [
    NotificationItem(
      id: 'n1',
      body: 'Omar invited you to vote on Saturday Padél ',
      time: '12m',
      unread: true,
      image: omar.avatar,
      outingId: 'o_padel_vote',
      groupId: 'g_weekend',
      action: true,
      createdAt: _now.subtract(const Duration(minutes: 12)),
      type: 'outing_voting',
    ),
    NotificationItem(
      id: 'n2',
      body: 'Layla confirmed Thursday Dinner at Lotus Kitchen',
      time: '1h',
      unread: true,
      image: layla.avatar,
      outingId: 'o_zooba',
      groupId: 'g_foodies',
      createdAt: _now.subtract(const Duration(hours: 1)),
      type: 'outing_confirmed',
    ),
    NotificationItem(
      id: 'n3',
      body: 'New message in Thursday Dinner at Lotus Kitchen',
      time: '2h',
      unread: true,
      image: mona.avatar,
      outingId: 'o_zooba',
      groupId: 'g_foodies',
      createdAt: _now.subtract(const Duration(hours: 2)),
      type: 'new_message',
    ),
    NotificationItem(
      id: 'n4',
      body: 'Karim created Friday Night Movie in Cinema Club',
      time: 'Yesterday',
      unread: false,
      image: karim.avatar,
      outingId: 'o_cinema_vote',
      groupId: 'g_cinema',
      createdAt: _now.subtract(const Duration(days: 1)),
      type: 'outing_created',
    ),
    NotificationItem(
      id: 'n5',
      body: 'You were added to Palm Foodies as Admin',
      time: '2d',
      unread: false,
      image: groups[1].image,
      groupId: 'g_foodies',
      createdAt: _now.subtract(const Duration(days: 2)),
      type: 'added_to_group',
    ),
    NotificationItem(
      id: 'n6',
      body: 'Hassan joined Palm Foodies',
      time: '3d',
      unread: false,
      image: hassan.avatar,
      groupId: 'g_foodies',
      createdAt: _now.subtract(const Duration(days: 3)),
      type: 'member_joined',
    ),
    NotificationItem(
      id: 'n7',
      body: 'Nadia invited you to Weekend Squad',
      time: '5d',
      unread: false,
      image: nadia.avatar,
      groupId: 'g_weekend',
      createdAt: _now.subtract(const Duration(days: 5)),
      type: 'group_invitation',
    ),
  ];

  // ─── Saved / drafts ─────────────────────────────────────────────────────

  static List<SavedOuting> savedOutings = [
    SavedOuting(
      id: 'o_felucca_past',
      title: 'Sunset Sail Evening',
      image: catalogPlaces[8].imageUrl,
      location: const PlaceLocation(
        name: 'Sunset Sail Pier',
        area: 'Riverfront',
        latitude: 30.0521,
        longitude: 31.2411,
      ),
    ),
    SavedOuting(
      id: 'sv_park',
      title: 'Olive Grove Picnic',
      image: catalogPlaces[7].imageUrl,
      location: const PlaceLocation(
        name: 'Olive Grove Gardens',
        area: 'Old Quarter',
        latitude: 30.0551,
        longitude: 31.2751,
      ),
    ),
  ];

  static List<OutingDraft> drafts = [
    OutingDraft(
      id: 'd_dawn',
      title: 'Coffee catch-up at Dawn Roast',
      image: catalogPlaces[9].imageUrl,
      location: const PlaceLocation(
        name: 'Dawn Roast Café',
        area: 'Sunrise Avenue',
        latitude: 30.1001,
        longitude: 31.3401,
      ),
      date: _now.add(const Duration(days: 4)),
      hour: 16,
      minute: 0,
      vibe: OutingVibe.food.index,
      groupId: 'g_foodies',
      selectedPlaces: [catalogPlaces[9]],
    ),
  ];

  // ─── Geocoding ──────────────────────────────────────────────────────────

  static const List<LocationHit> geocodingHits = [
    LocationHit(
      name: 'Palm District, Demo City',
      latitude: 30.1101,
      longitude: 31.3101,
    ),
    LocationHit(
      name: 'Maple Heights, Demo City',
      latitude: 29.9902,
      longitude: 31.2901,
    ),
    LocationHit(
      name: 'East Plaza, Demo City',
      latitude: 30.0405,
      longitude: 31.5202,
    ),
    LocationHit(
      name: 'Sunrise Avenue, Demo City',
      latitude: 30.1001,
      longitude: 31.3401,
    ),
    LocationHit(
      name: 'Green Belt, Demo City',
      latitude: 30.0701,
      longitude: 30.9901,
    ),
    LocationHit(
      name: 'Riverfront, Demo City',
      latitude: 30.0521,
      longitude: 31.2411,
    ),
    LocationHit(
      name: 'Olive Grove Gardens, Demo City',
      latitude: 30.0551,
      longitude: 31.2751,
    ),
  ];

  // ─── Snapshot / unread helpers ──────────────────────────────────────────

  static OutingSnapshot outingSnapshot() {
    return OutingSnapshot(
      outings: List<Outing>.from(outings),
      suggestions: List<GroupPlaceSuggestion>.from(suggestions),
      votesByOuting: Map<String, PlaceVote>.from(votesByOuting),
      attendanceByOuting: {
        for (final entry in attendanceByOuting.entries)
          entry.key: Map<String, AttendanceStatus>.from(entry.value),
      },
    );
  }

  static NotificationsFeed notificationsFeed() {
    final unread = notifications.where((n) => n.unread).length;
    return NotificationsFeed(
      unreadCount: unread,
      items: List<NotificationItem>.from(notifications),
    );
  }

  static GroupMember? memberById(String id) {
    for (final m in allMembers) {
      if (m.id == id) return m;
    }
    for (final g in groups) {
      for (final m in g.members) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  static GroupMember? memberByPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    for (final m in allMembers) {
      final p = m.phone?.replaceAll(RegExp(r'\s+'), '');
      if (p != null && p == normalized) return m;
    }
    return null;
  }

  static String groupsForMember(String id) {
    return groups
        .where((g) => g.members.any((m) => m.id == id))
        .map((g) => g.name)
        .join(', ');
  }

  static List<GroupMember> membersForOuting(Outing outing) {
    final groupId = outing.groupId;
    if (groupId == null) {
      return [
        for (final gid in outing.guestIds)
          memberById(gid) ??
              GroupMember(
                id: gid,
                name: gid,
                avatar: '',
                role: GroupRole.member,
              ),
      ];
    }
    final group = groups.cast<Group?>().firstWhere(
      (g) => g?.id == groupId,
      orElse: () => null,
    );
    return group?.members ?? const [];
  }

  static String specialEventImage(OutingOccasion occasion) {
    return switch (occasion) {
      OutingOccasion.birthday => birthdayCover,
      OutingOccasion.wedding => weddingCover,
      OutingOccasion.none => defaultCoverImage,
    };
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  static OutingSnapshot addOuting(Outing outing, {String? creatorId}) {
    final id = outing.id.isEmpty
        ? 'o_${DateTime.now().millisecondsSinceEpoch}'
        : outing.id;
    final created = outing.copyWith(
      id: id,
      createdById: creatorId ?? outing.createdById ?? currentUser.id,
      image: outing.image.isEmpty ? defaultCoverImage : outing.image,
    );
    outings = [created, ...outings.where((o) => o.id != id)];

    if (created.status == OutingStatus.voting &&
        created.votePlaces.length >= 2) {
      final options = [
        for (final p in created.votePlaces) VoteOption(p.placeId, p.name, 0, 0),
      ];
      votesByOuting[id] = PlaceVote(
        outingId: id,
        options: options,
        endsAt: _now.add(Duration(hours: created.voteDeadlineHours ?? 24)),
        suggestedById: created.createdById,
      );
      suggestions = [
        GroupPlaceSuggestion(
          id: 's_$id',
          groupId: created.groupId ?? '',
          title: created.title,
          places: created.votePlaces,
          deadlineHours: created.voteDeadlineHours ?? 24,
          createdBy: currentUser.name,
          outingId: id,
        ),
        ...suggestions.where((s) => s.outingId != id),
      ];
    }

    final memberId = created.createdById ?? currentUser.id;
    attendanceByOuting[id] = {memberId: AttendanceStatus.going};
    _syncGroupOutingCounts();
    return outingSnapshot();
  }

  static OutingSnapshot suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  }) {
    final id = 'o_${DateTime.now().millisecondsSinceEpoch}';
    final outing = Outing(
      id: id,
      image: (image == null || image.isEmpty) ? places.first.imageUrl : image,
      title: title,
      meta: '${places.first.area} · Voting',
      date: _fmtDate(scheduledAt ?? _now.add(const Duration(days: 2))),
      time: '7:00 PM',
      going: 1,
      groupId: groupId,
      status: OutingStatus.voting,
      votePlaces: places,
      voteDeadlineHours: deadlineHours,
      suggestedBy: createdBy,
      scheduledAt: scheduledAt ?? _now.add(const Duration(days: 2, hours: 19)),
      createdById: createdById ?? currentUser.id,
    );
    return addOuting(outing, creatorId: createdById);
  }

  static OutingSnapshot selectVote(String outingId, int optionIndex) {
    final vote = votesByOuting[outingId];
    if (vote == null ||
        vote.finalized ||
        optionIndex < 0 ||
        optionIndex >= vote.options.length) {
      return outingSnapshot();
    }
    final chosen = vote.options[optionIndex];
    final selected = List<String>.from(vote.cuserOptionIds);
    final wasSelected = selected.contains(chosen.placeId);
    if (wasSelected) {
      selected.remove(chosen.placeId);
    } else {
      selected.add(chosen.placeId);
    }

    final updated = <VoteOption>[];
    for (final option in vote.options) {
      var count = option.votes;
      if (option.placeId == chosen.placeId) {
        count = wasSelected ? (count - 1).clamp(0, 999) : count + 1;
      }
      updated.add(option.copyWith(votes: count));
    }
    final total = updated.fold<int>(0, (a, o) => a + o.votes);
    final withPercent = [
      for (final o in updated)
        o.copyWith(percent: total == 0 ? 0 : ((o.votes / total) * 100).round()),
    ];
    votesByOuting[outingId] = vote.copyWith(
      options: withPercent,
      cuserOptionIds: selected,
    );
    return outingSnapshot();
  }

  static OutingSnapshot clearVotes(String outingId) {
    final vote = votesByOuting[outingId];
    if (vote == null || vote.finalized || vote.cuserOptionIds.isEmpty) {
      return outingSnapshot();
    }
    final selected = vote.cuserOptionIds.toSet();
    final updated = [
      for (final option in vote.options)
        option.copyWith(
          votes: selected.contains(option.placeId)
              ? (option.votes - 1).clamp(0, 999)
              : option.votes,
        ),
    ];
    final total = updated.fold<int>(0, (a, o) => a + o.votes);
    votesByOuting[outingId] = vote.copyWith(
      options: [
        for (final o in updated)
          o.copyWith(
            percent: total == 0 ? 0 : ((o.votes / total) * 100).round(),
          ),
      ],
      clearCuserOptions: true,
    );
    return outingSnapshot();
  }

  static OutingSnapshot finalizeVote(String outingId) {
    final vote = votesByOuting[outingId];
    if (vote == null || vote.cuserOptionIds.isEmpty) {
      return outingSnapshot();
    }
    votesByOuting[outingId] = vote.copyWith(finalized: true);
    return outingSnapshot();
  }

  static OutingSnapshot setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  }) {
    final vote = votesByOuting[outingId];
    if (vote != null && vote.finalized && memberId == currentUser.id) {
      return outingSnapshot();
    }

    final map = Map<String, AttendanceStatus>.from(
      attendanceByOuting[outingId] ?? {},
    );
    map[memberId] = status;
    attendanceByOuting[outingId] = map;

    if (status == AttendanceStatus.notGoing && memberId == currentUser.id) {
      clearVotes(outingId);
    }

    final going = map.values.where((s) => s == AttendanceStatus.going).length;
    outings = [
      for (final o in outings)
        if (o.id == outingId) o.copyWith(going: going) else o,
    ];
    return outingSnapshot();
  }

  static OutingSnapshot refreshLifecycle() {
    final now = DateTime.now();
    outings = [
      for (final o in outings)
        if (o.scheduledAt != null && !o.scheduledAt!.isAfter(now))
          o.copyWith(status: OutingStatus.past)
        else
          o,
    ];
    return outingSnapshot();
  }

  static Group upsertGroup(Group group) {
    final existing = groups.indexWhere((g) => g.id == group.id);
    if (existing >= 0) {
      groups = [...groups]..[existing] = group;
    } else {
      groups = [group, ...groups];
    }
    return group;
  }

  static Group? addMember(String groupId, GroupMember member) {
    final index = groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return null;
    final group = groups[index];
    if (group.containsMember(id: member.id, phone: member.phone)) {
      return group;
    }
    final updated = group.copyWith(members: [...group.members, member]);
    groups = [...groups]..[index] = updated;
    return updated;
  }

  static Group? removeMember(String groupId, String memberId) {
    final index = groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return null;
    final group = groups[index];
    final updated = group.copyWith(
      members: [
        for (final member in group.members)
          if (member.id != memberId) member,
      ],
    );
    groups = [...groups]..[index] = updated;
    return updated;
  }

  /// Removes the current user from the group. Ownership transfer is not faked —
  /// if the owner leaves and others remain, the mock keeps remaining members as-is
  /// (backend decides transfer). Empty groups are dropped from the list.
  static bool leaveGroup(String groupId) {
    final index = groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return false;
    final group = groups[index];
    final remaining = [
      for (final member in group.members)
        if (member.id != currentUser.id) member,
    ];
    if (remaining.isEmpty) {
      groups = [
        for (final g in groups)
          if (g.id != groupId) g,
      ];
      return true;
    }
    groups = [...groups]..[index] = group.copyWith(members: remaining);
    return true;
  }

  static int markNotificationRead(String id) {
    notifications = [
      for (final n in notifications)
        if (n.id == id) n.copyWith(unread: false) else n,
    ];
    return notifications.where((n) => n.unread).length;
  }

  static int markAllNotificationsRead() {
    notifications = [for (final n in notifications) n.copyWith(unread: false)];
    return 0;
  }

  static void updateCurrentUser({
    String? name,
    String? imageUrl,
    String? phone,
    String? email,
  }) {
    currentUser = currentUser.copyWith(
      name: name,
      imageUrl: imageUrl,
      phone: phone,
      email: email,
    );
  }

  static void _syncGroupOutingCounts() {
    groups = [
      for (final g in groups)
        g.copyWith(outings: outings.where((o) => o.groupId == g.id).length),
    ];
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${_weekday(d.weekday)}, ${d.day} ${months[d.month - 1]}';
  }

  static String _weekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
