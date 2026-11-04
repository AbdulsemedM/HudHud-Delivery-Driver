import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/job_status.dart';

void main() {
  group('JobStatus.label', () {
    test('known statuses including COD confirmed', () {
      expect(JobStatus.label('confirmed'), 'Confirmed');
      expect(JobStatus.label('ready_for_pickup'), 'Ready for pickup');
      expect(JobStatus.label('EN_ROUTE_DROPOFF'), 'Heading to drop-off');
      expect(JobStatus.label(' delivered '), 'Delivered');
    });

    test('unknown statuses are humanised, never raw keys', () {
      expect(JobStatus.label('awaiting_vendor_review'), 'Awaiting vendor review');
      expect(JobStatus.label('on-hold'), 'On hold');
    });

    test('empty and placeholder values', () {
      expect(JobStatus.label(null), '—');
      expect(JobStatus.label(''), '—');
      expect(JobStatus.label('—'), '—');
      expect(JobStatus.label('___'), '—');
    });
  });

  group('JobStatus.color', () {
    test('confirmed is an in-progress color and unknown is grey', () {
      expect(JobStatus.color('confirmed'), Colors.blue);
      expect(JobStatus.color('delivered'), Colors.green);
      expect(JobStatus.color('something_new'), Colors.grey);
      expect(JobStatus.color(null), Colors.grey);
    });
  });
}
