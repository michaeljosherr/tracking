import 'package:flutter/material.dart';

/// Used so [HubSelectScreen] can rescan when it becomes visible again after a
/// route on top of it is popped ([RouteAware.didPopNext]).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
