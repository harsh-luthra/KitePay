class PageState<T> {
  List<T> items;
  String? nextCursor;
  bool hasMore;
  bool loadingMore;

  PageState({
    List<T>? items,
    this.nextCursor,
    this.hasMore = true,
    this.loadingMore = false,
  }) : items = items ?? [];
}
