import 'package:flutter_test/flutter_test.dart';
import 'package:youpji_frontend/models/itinerary_model.dart';
import 'package:youpji_frontend/models/chat_model.dart';
import 'package:youpji_frontend/models/replan_model.dart';

void main() {
  group('Itinerary Models JSON Parsing', () {
    test('ItineraryPlanResponse parses full backend payload', () {
      final json = {
        'itinerary_id': '00000000-0000-0000-0000-000000000001',
        'summary': {
          'title': '安顺2日自驾',
          'origin': '贵阳',
          'destination': '安顺',
          'days': 2,
          'people': 2,
          'mode': 'standard',
          'total_distance_km': 280.5,
          'drive_hours': 3.8,
          'ticket_cost': 700,
        },
        'days': [
          {
            'day_index': 0,
            'date': '2026-10-01',
            'title': '天龙屯堡与龙宫溶洞',
            'items': [
              {
                'item_type': 'attraction',
                'start_time': '09:50',
                'end_time': '12:20',
                'title': '平坝区天龙屯堡',
                'ref_id': 'uuid-tianlong',
                'cost': 60,
                'verification_status': 'verified',
              }
            ],
          }
        ],
        'budget': {
          'limit': 2000,
          'transport': 350,
          'lodging': 400,
          'tickets': 700,
          'food': 400,
          'parking': 0,
          'other': 0,
          'reserve': 0,
          'total': 1850,
        },
        'warnings': [
          {
            'code': 'opening_hours_conflict',
            'message': '到达时间接近闭园时间，请注意游览安全',
          }
        ],
        'algo_version': 'rule-budget-v2',
      };

      final plan = ItineraryPlanResponse.fromJson(json);
      expect(plan.itineraryId, '00000000-0000-0000-0000-000000000001');
      expect(plan.summary.title, '安顺2日自驾');
      expect(plan.days.length, 1);
      expect(plan.days[0].items[0].title, '平坝区天龙屯堡');
      expect(plan.days[0].items[0].cost, 60);
      expect(plan.days[0].items[0].verificationStatus, 'verified');
      expect(plan.budget.total, 1850);
      expect(plan.budget.limit, 2000);
      expect(plan.warnings.length, 1);
      expect(plan.warnings[0].code, 'opening_hours_conflict');
    });

    test('ChatResponse parses sources, session_id and suggestions', () {
      final json = {
        'reply': '黄果树瀑布门票为160元/人（省政府名录官方核验）。',
        'session_id': 'sess-123',
        'sources': ['贵州省人民政府景区名录', '黄果树景区官方须知'],
        'suggestions': ['将黄果树加入两日游行程', '查看黄果树周边酒店'],
      };

      final chat = ChatResponse.fromJson(json);
      expect(chat.reply.contains('160元'), isTrue);
      expect(chat.sessionId, 'sess-123');
      expect(chat.sources.length, 2);
      expect(chat.suggestions.length, 2);
    });

    test('ReorderDayRequest serializes to exact backend EditOp contract', () {
      final req = ReorderDayRequest(
        itineraryId: 'itinerary-uuid-001',
        dayIndex: 0,
        orderedAttractionIds: ['uuid-longgong', 'uuid-tianlong'],
      );

      final json = req.toJson();
      expect(json['itinerary_id'], 'itinerary-uuid-001');
      expect(json['edit_op']['type'], 'reorder_day');
      expect(json['edit_op']['day_index'], 0);
      expect(json['edit_op']['ordered_attraction_ids'], ['uuid-longgong', 'uuid-tianlong']);
    });
  });
}
