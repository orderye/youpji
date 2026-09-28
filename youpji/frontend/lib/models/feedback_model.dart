/// 行程反馈提交模型

class FeedbackRequest {
  final int rating; // 1-5
  final String comment;
  final List<String> images;

  FeedbackRequest({
    required this.rating,
    required this.comment,
    this.images = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
      if (images.isNotEmpty) 'images': images,
    };
  }
}
