
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'package:thingsboard_app/config/routes/v2/redirects/redirect.dart';
import 'package:thingsboard_app/config/routes/v2/routes_config/routes/login_routes.dart';
import 'package:thingsboard_app/config/routes/v2/routes_config/routes/noauth_routes.dart';
import 'package:thingsboard_app/config/routes/v2/routes_config/routes/ui_utils_routes.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

bool isLoginPath(GoRouterState state) {
  return state.uri.pathSegments.contains('login');
}

class AuthRedirect implements Redirect {
  @override
  Future<String?> redirect(
    BuildContext context,
    GoRouterState state,
    Ref ref,
  ) async {
    final login = ref.read(loginProvider);
    final path = state.fullPath;
    final client = getIt<ITbClientService>().client;
    final isAuthenticated = client.isAuthenticated();

    if (path == LoginRoutes.login + LoginRoutes.mfaConfigure) {
      return null;
    }
    if (path == UiUtilsRoutes.qrCodeScan) {
      return null;
    }
    if (path == noAuthPath) {
      return null;
    }
    final loginPath = isLoginPath(state);
    if (!isAuthenticated && !loginPath) {
      return '/login${path?.isEmpty == true ? '' : '?redirect=$path'}';
    }

    if (isAuthenticated && isLoginPath(state)) {
      return '/home';
    }
    return null;
  }
}
