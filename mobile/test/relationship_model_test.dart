import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/relationship_model.dart';

void main() {
  group('RelationshipModel Contract Tests', () {
    test('parses backend canonical response with monitorId and invitationCode', () {
      final backendJson = {
        'id': 'rel-uuid-001',
        'monitoredUserId': 'user-monitored-1',
        'monitorId': 'user-guardian-2',
        'status': 'ACCEPTED',
        'invitationCode': 'CARE-998877',
        'label': 'Mẹ yêu',
        'monitor': {
          'id': 'user-guardian-2',
          'email': 'guardian@example.com',
          'fullName': 'Nguyễn Con Gái',
        },
        'monitored': {
          'id': 'user-monitored-1',
          'email': 'mom@example.com',
          'fullName': 'Trần Mẹ Hiền',
        },
        'created_at': '2026-10-07T08:00:00.000Z',
      };

      final rel = RelationshipModel.fromJson(backendJson);
      expect(rel.id, 'rel-uuid-001');
      expect(rel.monitoredUserId, 'user-monitored-1');
      expect(rel.monitorUserId, 'user-guardian-2');
      expect(rel.monitorId, 'user-guardian-2');
      expect(rel.inviteCode, 'CARE-998877');
      expect(rel.invitationCode, 'CARE-998877');
      expect(rel.status, RelationshipStatus.ACCEPTED);
      expect(rel.label, 'Mẹ yêu');
      expect(rel.monitorUser, isNotNull);
      expect(rel.monitorUser!.fullName, 'Nguyễn Con Gái');
      expect(rel.monitoredUser, isNotNull);
      expect(rel.monitoredUser!.fullName, 'Trần Mẹ Hiền');
    });

    test('supports legacy and snake_case keys for backward compatibility', () {
      final legacyJson = {
        'id': 'rel-legacy-002',
        'monitored_user_id': 'user-m-2',
        'monitor_user_id': 'user-g-2',
        'status': 'REVOKED',
        'invite_code': 'OLD-123',
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final rel = RelationshipModel.fromJson(legacyJson);
      expect(rel.id, 'rel-legacy-002');
      expect(rel.monitoredUserId, 'user-m-2');
      expect(rel.monitorUserId, 'user-g-2');
      expect(rel.inviteCode, 'OLD-123');
      expect(rel.status, RelationshipStatus.SUSPENDED); // REVOKED maps to SUSPENDED
    });
  });
}
