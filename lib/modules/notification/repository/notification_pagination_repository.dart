import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:thingsboard_app/modules/notification/controllers/notification_query_ctrl.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class NotificationPaginationRepository {
  NotificationPaginationRepository({
    required this.notificationQueryPageCtrl,
    required this.tbClient,
  });

  final NotificationQueryCtrl notificationQueryPageCtrl;
  final ThingsboardClient tbClient;
  late final PagingController<PushNotificationQuery, PushNotification>
      pagingController;

  bool _noMorePages = false;

  void init() {
    _noMorePages = false;
    pagingController =
        PagingController<PushNotificationQuery, PushNotification>(
      getNextPageKey: (state) {
        if (state.pages == null || state.pages!.isEmpty) {
          _noMorePages = false;
        }
        if (_noMorePages) return null;
        if (state.keys == null || state.keys!.isEmpty) {
          return notificationQueryPageCtrl.value.pageKey;
        }
        return notificationQueryPageCtrl.nextPageKey(state.keys!.last);
      },
      fetchPage: (pageKey) async {
        final pageData = await tbClient
            .getNotificationService()
            .getNotifications(pageKey);
        _noMorePages = !pageData.hasNext;
        return pageData.data;
      },
    );

    notificationQueryPageCtrl.addListener(_didChangePageKeyValue);
  }

  void dispose() {
    notificationQueryPageCtrl.removeListener(_didChangePageKeyValue);
    pagingController.dispose();
  }

  void refresh() {
    _noMorePages = false;
    pagingController.refresh();
  }

  void _didChangePageKeyValue() {
    _noMorePages = false;
    pagingController.refresh();
  }
}
