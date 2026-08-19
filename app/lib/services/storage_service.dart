import '../models/scan_record.dart';

abstract interface class StorageService {
  Future<List<ScanRecord>> getRecords();

  Future<void> saveRecord(ScanRecord record);

  Future<void> deleteRecord(String id);

  Future<void> clearRecords();
}
