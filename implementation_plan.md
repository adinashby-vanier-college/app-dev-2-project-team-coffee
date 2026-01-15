# FriendMap Implementation Plan

## ✅ Phase 1: Core UI Components
- [x] **Notifications List UI**
  - [x] Create `NotificationModel`
  - [x] Create `NotificationService`
  - [x] Create `NotificationsPage`
  - [x] Create `NotificationBell` widget

- [x] **Moments Feature**
  - [x] Create `MomentModel`
  - [x] Create `MomentsService`
  - [x] Create `MomentsPage`
  - [x] Create `MomentDetailPage`
  - [x] Create `MomentFormPage`
  - [x] Add "Moments" tab to `NavBar`

- [x] **Shareable Web Form**
  - [x] Create `web/moment/index.html`
  - [x] Configure `firebase.json`
  - [x] Integrate `share_plus`

## ✅ Phase 2: Navigation & UX Improvements
- [x] **Navigation Updates**
  - [x] Add `NotificationBell` to AppBars
  - [x] Implement Android Back Button handling (`PopScope`)
  - [x] Add "Moments" to Bottom Navigation

- [x] **Friend Features**
  - [x] Create `FriendProfilePage` (read-only profile + saved locations)
  - [x] Update `FriendsPage` navigation (tap friend -> profile)
  - [x] **Map Integration**: Display friend pins on the map
    - [x] Update `UserModel` with location
    - [x] Sync user location to Firestore
    - [x] Render friend markers in `MapView.jsx`
    - [x] Seed dummy friend data for testing "3 pins"

## 🚀 Next Steps
1. **Deploy Web Form**: Run `firebase deploy --only hosting`
2. **User Testing**:
   - Verify specific friend locations appear on map.
   - Verify tapping friend in list opens profile.
   - Verify friend's saved locations load.
