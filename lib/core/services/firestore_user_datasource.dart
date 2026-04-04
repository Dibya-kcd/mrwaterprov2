import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUserDataSource {
  FirestoreUserDataSource._();
  static final instance = FirestoreUserDataSource._();

  CollectionReference<Map<String, dynamic>> users(String companyId) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('users');
  }

  Stream<List<Map<String, dynamic>>> watchUsers(String companyId) {
    if (companyId.isEmpty) return const Stream.empty();
    return users(companyId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{'id': doc.id, ...data};
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getUser(String companyId, String userId) async {
    final doc = await users(companyId).doc(userId).get();
    return doc.exists ? <String, dynamic>{'id': doc.id, ...doc.data()!} : null;
  }

  Future<void> setUser(String companyId, String userId, Map<String, dynamic> value) async {
    await users(companyId).doc(userId).set(value, SetOptions(merge: true));
  }

  Future<void> updateUser(String companyId, String userId, Map<String, dynamic> value) async {
    await users(companyId).doc(userId).update(value);
  }

  Future<void> deleteUser(String companyId, String userId) async {
    await users(companyId).doc(userId).delete();
  }
}
