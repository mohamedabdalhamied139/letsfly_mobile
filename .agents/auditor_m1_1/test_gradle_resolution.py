import os

root_dir = os.path.abspath('android')
app_dir = os.path.abspath('android/app')

keystore_properties_file = os.path.join(root_dir, 'key.properties')
print('rootProject.file("key.properties"):', keystore_properties_file, os.path.exists(keystore_properties_file))

store_path = 'letsfly-release.jks'
store_file_in_app = os.path.join(app_dir, store_path)
store_file_in_root = os.path.join(root_dir, store_path)

print('file(storePath) in app:', store_file_in_app, os.path.exists(store_file_in_app))
print('rootProject.file(storePath):', store_file_in_root, os.path.exists(store_file_in_root))
assert os.path.exists(store_file_in_app), 'storeFile must exist in android/app!'
print('Gradle path resolution logic: FULLY VALID')
