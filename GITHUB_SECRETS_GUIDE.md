# GitHub Secrets Configuration Guide

This guide shows you how to configure all the secrets needed for automated deployment of both the web app and Android APK.

## Required GitHub Secrets

Go to: **Settings > Secrets and variables > Actions > New repository secret**

### Firebase Secrets
1. **FIREBASE_API_KEY**
   - Value: `AIzaSyDr6JHIReYMAT-gff_OZZtU2aaAj0zt2ho`

2. **FIREBASE_API_KEY_ANDROID**
   - Value: `AIzaSyArDnXqUojZJVBUAcnW_QWIH3h57nBE6Ic`

3. **FIREBASE_AUTH_DOMAIN**
   - Value: `mrwaterprov1-54c3f.firebaseapp.com`

4. **FIREBASE_DATABASE_URL**
   - Value: `https://mrwaterprov1-54c3f-default-rtdb.firebaseio.com`

5. **FIREBASE_PROJECT_ID**
   - Value: `mrwaterprov1-54c3f`

6. **FIREBASE_STORAGE_BUCKET**
   - Value: `mrwaterprov1-54c3f.firebasestorage.app`

7. **FIREBASE_MESSAGING_SENDER_ID**
   - Value: `199429585160`

8. **FIREBASE_APP_ID_WEB**
   - Value: `1:199429585160:web:919155f8d921ab0790d4bd`

9. **FIREBASE_APP_ID_ANDROID**
   - Value: `1:199429585160:android:de08ce0929fc6f6190d4bd`

### Google Services JSON
9. **GOOGLE_SERVICES_JSON**
   - Value: Copy the entire JSON block below:
   ```json
   {
     "project_info": {
       "project_number": "199429585160",
       "firebase_url": "https://mrwaterprov1-54c3f-default-rtdb.firebaseio.com",
       "project_id": "mrwaterprov1-54c3f",
       "storage_bucket": "mrwaterprov1-54c3f.firebasestorage.app"
     },
     "client": [
       {
         "client_info": {
           "mobilesdk_app_id": "1:199429585160:android:de08ce0929fc6f6190d4bd",
           "android_client_info": {
             "package_name": "com.mrwater.mrwaterprov1"
           }
         },
         "oauth_client": [
           {
             "client_id": "199429585160-9r7no26sm14ilmdoai4jfcufvqbo8c2v.apps.googleusercontent.com",
             "client_type": 3
           }
         ],
         "api_key": [
           {
             "current_key": "AIzaSyArDnXqUojZJVBUAcnW_QWIH3h57nBE6Ic"
           }
         ],
         "services": {
           "appinvite_service": {
             "other_platform_oauth_client": [
               {
                 "client_id": "199429585160-9r7no26sm14ilmdoai4jfcufvqbo8c2v.apps.googleusercontent.com",
                 "client_type": 3
               }
             ]
           }
         }
       }
     ],
     "configuration_version": "1"
   }
   ```

### Keystore Secrets (for APK Signing)
10. **KEYSTORE_BASE64**
    - Value: `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`

11. **KEYSTORE_STORE_PASSWORD**
    - Value: `Chanty@123`

12. **KEYSTORE_KEY_PASSWORD**
    - Value: `Chanty@123`

13. **KEYSTORE_KEY_ALIAS**
    - Value: `mrwater-key`

## How to Add Secrets

1. Go to your GitHub repository
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret with the exact names and values above

## Testing the Workflow

After adding all secrets:

```bash
git add .
git commit -m "Update deployment workflow with individual secrets"
git push
```

The workflow will automatically run and deploy both the web app and APK.

## What Gets Deployed

- **Web App**: Deployed to GitHub Pages at `https://[username].github.io/mrwaterprov1/`
- **Android APK**: Available as artifact download and GitHub release
