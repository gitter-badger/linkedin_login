import 'dart:async';

import 'package:linkedin_login/redux/app_state.dart';
import 'package:linkedin_login/src/client/actions.dart';
import 'package:linkedin_login/src/utils/logger.dart';
import 'package:linkedin_login/src/utils/startup/graph.dart';
import 'package:redux_epics/redux_epics.dart';
import 'package:rxdart/rxdart.dart';

Epic<AppState> _fetchAccessTokenEpic(Graph graph) => (
      Stream<dynamic> actions,
      EpicStore<AppState> store,
    ) {
      return actions.whereType<FetchAccessCode>().switchMap(
            (action) => _fetchAccessTokenUser(action, graph),
          );
    };

Stream<dynamic> _fetchAccessTokenUser(
  FetchAccessCode action,
  Graph graph,
) async* {
  try {
    log('LinkedInAuth-steps: Fetching access token...');

    final response = await graph.authorizationRepository.fetchAccessTokenCode(
      redirectedUrl: action.url,
      clientId: graph.linkedInConfiguration.clientId,
      clientSecret: graph.linkedInConfiguration.clientSecret,
      clientState: graph.linkedInConfiguration.state,
      client: graph.httpClient,
    );

    log(
      'LinkedInAuth-steps: Fetching access token... DONE,'
      ' isEmpty: ${response?.accessToken?.accessToken?.isEmpty}',
    );
    yield FetchAccessCodeSucceededAction(response.accessToken);
    yield FetchLinkedInUser(response.accessToken);
  } on Exception catch (e, s) {
    logError('Unable to fetch access token code', error: e, stackTrace: s);
    yield FetchAccessCodeFailedAction(e);
  }
}

Epic<AppState> _fetchLinkedUserProfileEpic(Graph graph) => (
      Stream<dynamic> actions,
      EpicStore<AppState> store,
    ) {
      return actions.whereType<FetchLinkedInUser>().switchMap(
            (action) => _fetchLinkedInProfile(
              action,
              graph,
            ),
          );
    };

Stream<dynamic> _fetchLinkedInProfile(
  FetchLinkedInUser action,
  Graph graph,
) async* {
  try {
    log('LinkedInAuth-steps: Fetching full profile...');

    final user = await graph.userRepository.fetchFullProfile(
      token: action.token,
      projection: graph.linkedInConfiguration.projection,
      client: graph.httpClient,
    );

    log('LinkedInAuth-steps: Fetching full profile... DONE');

    yield FetchLinkedInUserSucceededAction(user);
  } on Exception catch (e, s) {
    logError('Unable to fetch LinkedIn profile', error: e, stackTrace: s);
    yield FetchLinkedInUserFailedAction(e);
  }
}

Epic<AppState> clientEpics(Graph graph) => combineEpics<AppState>([
      _fetchAccessTokenEpic(graph),
      _fetchLinkedUserProfileEpic(graph),
    ]);
