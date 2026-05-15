import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

abstract base class PaginationRepository<T, B> {
  PaginationRepository({required this.pageKeyController}) {
    init();
  }

  late final PagingController<T, B> pagingController;
  final PageKeyController<T> pageKeyController;

  bool _noMorePages = false;

  void init() {
    _noMorePages = false;
    pagingController = PagingController<T, B>(
      getNextPageKey: (state) {
        if (state.pages == null || state.pages!.isEmpty) {
          _noMorePages = false;
        }
        if (_noMorePages) return null;
        if (state.keys == null || state.keys!.isEmpty) {
          return pageKeyController.value.pageKey;
        }
        return pageKeyController.nextPageKey(state.keys!.last);
      },
      fetchPage: (pageKey) async {
        final pageData = await fetchPageData(pageKey);
        _noMorePages = !pageData.hasNext;
        return pageData.data;
      },
    );

    pageKeyController.addListener(_didChangePageKeyValue);
  }

  void dispose() {
    pageKeyController.removeListener(_didChangePageKeyValue);
    pagingController.dispose();
  }

  void refresh() {
    _noMorePages = false;
    pagingController.refresh();
  }

  Future<PageData<B>> fetchPageData(T pageKey);

  void _didChangePageKeyValue() {
    _refreshPagingController();
  }

  void _refreshPagingController() {
    _noMorePages = false;
    pagingController.refresh();
  }
}
