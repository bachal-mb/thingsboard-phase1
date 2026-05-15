import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:thingsboard_app/config/themes/app_colors.dart';
import 'package:thingsboard_app/config/themes/design_tokens.dart';
import 'package:thingsboard_app/config/themes/tb_text_styles.dart';
import 'package:thingsboard_app/generated/l10n.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/overlay_service/i_overlay_service.dart';
import 'package:thingsboard_app/utils/ui/pagination_widgets/first_page_exception_widget.dart';
import 'package:thingsboard_app/utils/utils.dart';

typedef EntityTapFunction<T> = Function(T entity);
typedef EntityCardWidgetBuilder<T> =
    Widget Function(BuildContext context, T entity);

class EntityCardSettings {
  EntityCardSettings({this.dropShadow = true});
  bool dropShadow;
}

mixin EntitiesBase<T, P> {
  final entityDateFormat = DateFormat('yyyy-MM-dd');

  String get title;

  String get noItemsFoundText;

  Future<PageData<T>> fetchEntities(P pageKey, {bool refresh = false});

  Future<void> onRefresh() => Future.value();

  Widget? buildHeading(BuildContext context) => null;

  Key? getKey(T entity) => null;

  Widget buildEntityListCard(BuildContext context, T entity) {
    return Text(S.of(context).notImplemented);
  }

  Widget buildEntityListWidgetCard(BuildContext context, T entity) {
    return Text(S.of(context).notImplemented);
  }

  Widget buildEntityGridCard(BuildContext context, T entity) {
    return Text(S.of(context).notImplemented);
  }

  double? gridChildAspectRatio() => null;

  EntityCardSettings entityListCardSettings(T entity) => EntityCardSettings();

  EntityCardSettings entityGridCardSettings(T entity) => EntityCardSettings();

  void onEntityTap(T entity, WidgetRef ref);
}

mixin ContactBasedBase<T extends ContactBased, P> on EntitiesBase<T, P> {
  @override
  Widget buildEntityListCard(BuildContext context, T contact) {
    final address = Utils.contactToShortAddress(contact);
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(borderRadius: DesignTokens.borderRadiusSmall),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.group, color: AppColors.iconDisabled),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        contact.getName(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TbTextStyles.labelLarge.copyWith(
                          color: Colors.black.withValues(alpha: .87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      entityDateFormat.format(
                        DateTime.fromMillisecondsSinceEpoch(
                          contact.createdTime!,
                        ),
                      ),
                      style: TbTextStyles.bodyMedium.copyWith(
                        color: Colors.black.withValues(alpha: .54),
                      ),
                    ),
                  ],
                ),

                if (contact.email != null)
                  Text(
                    contact.email!,
                    style: TbTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                if (address != null)
                  Text(
                    address,
                    style: TbTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

abstract class PageKeyController<P> extends ValueNotifier<PageKeyValue<P>> {
  PageKeyController(P initialPageKey) : super(PageKeyValue(initialPageKey));

  P nextPageKey(P pageKey);
}

class PageKeyValue<P> {
  PageKeyValue(this.pageKey);
  final P pageKey;
}

class PageLinkController extends PageKeyController<PageLink> {
  PageLinkController({int pageSize = 20, String? searchText})
    : super(
        PageLink(
          pageSize,
          0,
          searchText,
          SortOrder('createdTime', Direction.DESC),
        ),
      );

  @override
  PageLink nextPageKey(PageLink pageKey) => pageKey.nextPageLink();

  void onSearchText(String searchText) {
    value.pageKey.page = 0;
    value.pageKey.textSearch = searchText;
    notifyListeners();
  }
}

class TimePageLinkController extends PageKeyController<TimePageLink> {
  TimePageLinkController({int pageSize = 20, String? searchText})
    : super(
        TimePageLink(
          pageSize,
          0,
          searchText,
          SortOrder('createdTime', Direction.DESC),
        ),
      );

  @override
  TimePageLink nextPageKey(TimePageLink pageKey) => pageKey.nextPageLink();

  void onSearchText(String searchText) {
    value.pageKey.page = 0;
    value.pageKey.textSearch = searchText;
    notifyListeners();
  }
}

abstract class BaseEntitiesWidget<T, P> extends ConsumerStatefulWidget
    with EntitiesBase<T, P> {
  BaseEntitiesWidget(
    this.pageKeyController, {
    super.key,
    this.searchMode = false,
  });
  final bool searchMode;
  final PageKeyController<P> pageKeyController;

  @override
  Widget? buildHeading(BuildContext context) =>
      searchMode
          ? Text(
            S.of(context).searchResults,
            style: const TextStyle(
              color: Color(0xFFAFAFAF),
              fontSize: 16,
              height: 24 / 16,
            ),
          )
          : null;
}

abstract class BaseEntitiesState<T, P> extends ConsumerState<BaseEntitiesWidget<T, P>> {
  BaseEntitiesState();
  late PagingController<P, T> pagingController;
  Completer<void>? _refreshCompleter;
  bool _noMorePages = false;
  final IOverlayService overlayService = getIt();

  @override
  void initState() {
    super.initState();
    _setupController();
    widget.pageKeyController.addListener(_didChangePageKeyValue);
  }

  void _setupController() {
    _noMorePages = false;
    pagingController = PagingController<P, T>(
      getNextPageKey: (state) {
        if (state.pages == null || state.pages!.isEmpty) {
          _noMorePages = false;
        }
        if (_noMorePages) return null;
        if (state.keys == null || state.keys!.isEmpty) {
          return widget.pageKeyController.value.pageKey;
        }
        return widget.pageKeyController.nextPageKey(state.keys!.last);
      },
      fetchPage: (pageKey) async {
        overlayService.hideNotification();
        final pageData = await widget.fetchEntities(pageKey);
        _noMorePages = !pageData.hasNext;
        _refreshCompleter?.complete();
        _refreshCompleter = null;
        return pageData.data;
      },
    );
  }

  @override
  void didUpdateWidget(BaseEntitiesWidget<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageKeyController != oldWidget.pageKeyController) {
      oldWidget.pageKeyController.removeListener(_didChangePageKeyValue);
      widget.pageKeyController.addListener(_didChangePageKeyValue);
    }
  }

  @override
  void dispose() {
    widget.pageKeyController.removeListener(_didChangePageKeyValue);
    pagingController.dispose();
    super.dispose();
  }

  void _didChangePageKeyValue() {
    _noMorePages = false;
    pagingController.refresh();
  }

  Future<void> _refresh() {
    final completer = _refreshCompleter = Completer();
    _noMorePages = false;
    pagingController.refresh();
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => Future.wait([widget.onRefresh(), _refresh()]),
      child: PagingListener<P, T>(
        controller: pagingController,
        builder: (context, state, fetchNextPage) =>
            pagedViewBuilder(context, state, fetchNextPage),
      ),
    );
  }

  Widget pagedViewBuilder(
    BuildContext context,
    PagingState<P, T> state,
    NextPageCallback fetchNextPage,
  );

  Widget firstPageProgressIndicatorBuilder(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [RefreshProgressIndicator()],
          ),
        ),
      ],
    );
  }

  Widget newPageProgressIndicatorBuilder(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16, bottom: 16),
      child: Center(child: RefreshProgressIndicator()),
    );
  }

  Widget noItemsFoundIndicatorBuilder(BuildContext context) {
    return FirstPageExceptionIndicator(
      title: widget.noItemsFoundText,
      message: S.of(context).listIsEmptyText,
      onTryAgain:
          widget.searchMode
              ? null
              : () {
                _noMorePages = false;
                pagingController.refresh();
              },
    );
  }
}
