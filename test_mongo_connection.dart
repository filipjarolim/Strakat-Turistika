import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  print('🧪 Starting standalone MongoDB connection test...');

  // 1. Use User Provided Credentials directly for verification
  const connectionString = 'mongodb+srv://jarolimfilip07:QSRNlqVjCJQW5g5F@main.2x8zm.mongodb.net/st?retryWrites=true&w=majority';

  print('📝 Found connection string: $connectionString');

  // 2. Normalize URL (simulating Service logic)
  var url = connectionString;
  if (!url.contains('tls=') && !url.contains('ssl=')) {
     url += (url.contains('?') ? '&' : '?') + 'tls=true';
  }
  
  print('🔄 Connecting to: $url');

  // 3. Attempt Connection
  try {
    final db = await Db.create(url);
    await db.open();
    print('✅ Connection opened!');

    // List All Databases
    print('\n🗄️ Checking available databases on this cluster...');
    try {
      // Note: listDatabases might fail if the user doesn't have clusterAdmin role
       final databases = await db.listDatabases();
       print('   👉 Found ${databases.length} databases:');
       for (var d in databases) {
         print('      - ${d['name']} (Size: ${d['sizeOnDisk']})');
       }
    } catch (e) {
      print('   ⚠️ Could not list databases: $e');
    }

    print('\n📊 Collection Statistics:');
    final collections = await db.getCollectionNames();
    print('   Found ${collections.length} collections: $collections\n');
    
    for (final name in collections) {
      if (name == null) continue;
      if (name.startsWith('system.')) continue;
      
      try {
        final count = await db.collection(name).count();
        if (count > 0) {
           print('   📂 $name: $count documents');
           // If it's a user or visit collection, clarify schema 
           if (name.toLowerCase().contains('user') || name.toLowerCase().contains('visit')) {
              final sample = await db.collection(name).findOne();
              print('      👉 Sample ID: ${sample?['_id']}');
           }
        } else {
           print('   📂 $name: [EMPTY]');
        }
      } catch (e) {
        print('   ❌ Error checking $name: $e');
      }
    }

    await db.close();
    exit(0);
  } catch (e, stack) {
    print('❌ Connection failed:');
    print(e);
    print(stack);
    exit(1);
  }
}
