import { ownerResponse } from "../users/saved-location.controller.js";
import { GetMeetupResultsUseCase, RefreshMeetupResultsUseCase } from "../../usecases/meetups/meetup-result.usecases.js";
import {
  CancelMeetupSessionUseCase,
  GetMeetupReadinessUseCase,
  GetMeetupSessionUseCase,
  MeetupSessionWorkflow,
  InitializeGroupMeetupUseCase,
} from "../../usecases/meetups/meetup-session.usecases.js";
import {
  GetMeetupPreferencesUseCase, ResetMeetupPreferencesUseCase, UpdateMeetupPreferencesUseCase,
} from "../../usecases/meetups/meetup-preferences.usecases.js";
import {
  AddManualParticipantUseCase,
  CreateStandaloneMeetupUseCase,
  ListStandaloneParticipantsUseCase,
  RemoveManualParticipantUseCase,
  UpdateManualParticipantUseCase,
} from "../../usecases/meetups/standalone-meetup.usecases.js";

export class MeetupSessionController {
  constructor(flow = new MeetupSessionWorkflow()) {
    const initialize = new InitializeGroupMeetupUseCase(flow);
    const get = new GetMeetupSessionUseCase(flow);
    const results = new GetMeetupResultsUseCase(flow);
    const refreshResults = new RefreshMeetupResultsUseCase(results);
    const readiness = new GetMeetupReadinessUseCase(get);
    const preferences = new UpdateMeetupPreferencesUseCase(flow);
    const getPreferences = new GetMeetupPreferencesUseCase(flow);
    const resetPreferences = new ResetMeetupPreferencesUseCase(preferences);
    const cancel = new CancelMeetupSessionUseCase(flow);
    const standalone = new CreateStandaloneMeetupUseCase(flow);
    const list = new ListStandaloneParticipantsUseCase(flow);
    const add = new AddManualParticipantUseCase(flow);
    const update = new UpdateManualParticipantUseCase(flow);
    const remove = new RemoveManualParticipantUseCase(flow);
    this.initialize = ownerResponse((uid, req) =>
      initialize.execute(uid, req.params.groupId as string, req.body?.outing_id ?? null));
    this.get = ownerResponse((uid, req) => get.execute(uid, req.params.sessionId as string));
    this.results = ownerResponse((uid, req) => results.execute(uid, req.params.sessionId as string));
    this.calculation = ownerResponse((uid, req) =>
      results.execute(uid, req.params.sessionId as string, req.params.calculationId as string));
    this.calculate = ownerResponse((uid, req) => refreshResults.execute(uid, req.params.sessionId as string));
    this.readiness = ownerResponse((uid, req) => readiness.execute(uid, req.params.sessionId as string));
    this.getPreferences = ownerResponse((uid, req) => getPreferences.execute(uid, req.params.sessionId as string));
    this.updatePreferences = ownerResponse((uid, req) =>
      preferences.execute(uid, req.params.sessionId as string, req.body));
    this.resetPreferences = ownerResponse((uid, req) => resetPreferences.execute(uid, req.params.sessionId as string));
    this.filterOptions = ownerResponse(() => getPreferences.filterOptions());
    this.legacyPreferences = ownerResponse((uid, req) =>
      preferences.updateLegacy(uid, req.params.sessionId as string, req.body.optimization));
    this.cancel = ownerResponse((uid, req) => cancel.execute(uid, req.params.sessionId as string));
    this.createStandalone = ownerResponse(uid => standalone.execute(uid));
    this.listParticipants = ownerResponse((uid, req) => list.execute(uid, req.params.sessionId as string));
    this.addParticipant = ownerResponse((uid, req) =>
      add.execute(uid, req.params.sessionId as string, req.body), 201);
    this.updateParticipant = ownerResponse((uid, req) =>
      update.execute(uid, req.params.sessionId as string, req.params.participantId as string, req.body));
    this.removeParticipant = ownerResponse((uid, req) =>
      remove.execute(uid, req.params.sessionId as string, req.params.participantId as string));
  }

  readonly initialize;
  readonly get;
  readonly results;
  readonly calculation;
  readonly calculate;
  readonly readiness;
  readonly getPreferences;
  readonly updatePreferences;
  readonly resetPreferences;
  readonly filterOptions;
  readonly legacyPreferences;
  readonly cancel;
  readonly createStandalone;
  readonly listParticipants;
  readonly addParticipant;
  readonly updateParticipant;
  readonly removeParticipant;
}
