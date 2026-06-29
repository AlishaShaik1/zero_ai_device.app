/// Represents a single web search result from the Zero Search Gateway.
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
    );
  }

  @override
  String toString() => 'SearchResult(title: $title, url: $url)';
}
