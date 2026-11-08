# HudHud Rider (Driver) App: Manual Device Test Checklist (v1.0.3+21)

Run on a real Android phone and iPhone with a **driver** account (and a second
driver account for the "taken by another rider" cases). Mark each line Pass,
Fail or N/A, and note the device, OS and build.

Setup:
- Build with `--dart-define=BASE_URL=<staging api>/api`.
- Admin portal access, to create orders, toggle system dispatch per city,
  set exchange rates and put withdrawals on hold.
- One customer account in Addis Ababa (ETB) and one in Hargeisa (USD).

## 1. Sign-in, session and permissions
- [ ] Fresh install: walkthrough, then login, then delivery home. Location permission prompt appears.
- [ ] Deny location, then go online: you see a "Turn on location" or Settings dialog and stay offline.
- [ ] Allow "While using" only: an orange hint says background location is off.
- [ ] Allow "Always": no hint, and location keeps updating with the app in the background (check the admin rider map).
- [ ] Turn GPS off mid-shift: within about 1 minute the "Location not updating" link appears, and tapping it opens settings.
- [ ] Token expiry: revoke the token in admin (or log in on another device if single-session). The next API call goes to login, and logging back in restores the active job.
- [ ] Pending or suspended application: you go to the gate screen, and no offers show on top of it.

## 2. Online / offline
- [ ] Go online: you get a success snackbar, the "Available deliveries" and "Food orders nearby" buttons appear, and the location heartbeat starts.
- [ ] Go offline with no job: polling stops.
- [ ] Try to go offline **with an active delivery or an assigned food order**: you are blocked with "Finish your current delivery before going offline".
- [ ] Airplane mode, then toggle: you see a localized "No connection" message (not "AppException: …").

## 3. Food: system dispatch offers (city with dispatch ON)
- [ ] App in foreground, online: an order is created and becomes ready, and the full-screen offer opens within about 15 s (poll) or at once (push). The countdown is correct.
- [ ] Accept: the order screen opens. Pickup code is asked at **Picked up / start** (not at accept) when the restaurant uses one.
- [ ] Wrong pickup code: you see "That pickup code is not correct", the field clears, and you can retry.
- [ ] Decline (button or back gesture): the offer closes and the next rider gets it.
- [ ] Let it expire: "Offer expired", then it closes after about 1.5 s.
- [ ] Second rider accepts first, or the order is cancelled: "Another rider already has this order" or "no longer available", then it closes.
- [ ] Low wallet on a cash order: "Not eligible: low wallet balance…" and the offer stays open until it expires.
- [ ] Rider in the wrong city (move the rider's city in admin): "This order is in another city" and the offer closes.
- [ ] **App in background**: a push notification arrives. Tap it and the offer opens if still valid.
- [ ] **App killed**: a push notification arrives. Tap it and the app launches, passes splash, then the offer opens (not on top of splash or login). If it expired meanwhile, nothing opens.
- [ ] **Lost connection during accept** (toggle airplane mode right after tapping Accept): if the server took it, the order screen opens. Otherwise an error shows and you can tap Accept again.
- [ ] Ops assigns or unassigns an order (`food_dispatch_assigned` / `food_dispatch_unassigned` push): Assigned orders opens.

## 4. Food: legacy list (city with system dispatch OFF)
- [ ] Online: open "Food orders nearby" and ready orders in your city within the radius are listed. Offline: the list is empty with an explanation.
- [ ] Order with a restaurant pickup code: Accept goes straight to the order screen, and the 4-digit code is asked at "Picked up". A wrong code shows "That pickup code is not correct".
- [ ] Cash order with low wallet: red notice, and Accept is disabled.
- [ ] Accept: the order screen opens. Picked up, then Mark delivered, then it leaves Assigned orders.
- [ ] Turn system dispatch ON for the city while the list is open, then Accept: "HudHud assigns this order automatically…" and the row disappears (409 DISPATCH_OFFER_REQUIRED).
- [ ] A row that is your open offer shows the "Offered to you" chip, and Accept opens the full-screen offer.
- [ ] Already on a job, then Accept: the "Finish your current job" sheet appears with "View current job".

## 5. Gift orders
- [ ] Gift order: the contact shown is the **recipient** (name and phone), and Call and SMS work.
- [ ] Code required (setting on): Mark delivered without a code asks for it. A wrong code shows "N tries left". After 5 wrong codes you see the locked message and the field is disabled.
- [ ] Correct code: "Delivery completed".
- [ ] Code not required (setting off): Mark delivered completes directly.

## 6. Completion money edge cases
- [ ] Remove the USD/ETB exchange rate in admin, then complete a Hargeisa (USD) order: you see "exchange rate is missing… Nothing was charged" with **Retry**. Restore the rate, tap Retry, and it completes once (check the wallet ledger has one credit).
- [ ] Airplane mode while tapping Mark delivered: you see the connection message with Retry. Back online, Retry shows "Delivery completed" (the API answers "already completed" if the first request went through).
- [ ] COD order where the rider's wallet is too low to settle: "wallet balance is too low to settle this cash order", top up, then Retry.
- [ ] After completion: earnings show the rider's 80 % share of the delivery fee (compare with the admin order detail).

## 7. Parcels: single drop-off
- [ ] Accept from Available deliveries, then arrive at pickup.
- [ ] **Pay at pickup** parcel: Start trip opens the "Cash at pickup" sheet with the amount. "Not yet" keeps you at pickup. "Cash received" starts the trip.
- [ ] Pickup photo (optional) uploads and shows "Photo saved privately".
- [ ] **Camera denied** (deny the camera prompt, or turn it off in Settings): the "Camera access needed" dialog appears with Open Settings, and the app does **not** crash (iOS).
- [ ] Drop-off: handover code (4 digits for v2 parcels, 6 for older ones). A wrong code shows attempts left, and the lock shows the support state.
- [ ] `require_delivery_photo` ON: completing without a delivery photo shows "Take a photo of the delivered parcel before completing". With the photo it completes.
- [ ] Couldn't deliver, then pick a reason: the Return to sender dialog appears. Return photo, then Returned to sender, then the job closes. "Later" leaves it pending and support can mark it returned.
- [ ] Recipient pays cash or electronic at drop-off: collect, then complete.
- [ ] Prepaid parcel: the payout appears in the wallet after completion.

## 8. Parcels: multi-stop
- [ ] Stops are listed in order, and only the current stop has actions.
- [ ] For each stop: I have arrived, then the recipient's code, then a photo if required, then Delivered at this stop.
- [ ] Trying the old single "complete" on a multi-stop parcel: "This parcel has several drop-offs…" (PARCEL_USE_STOP_HANDOVER).
- [ ] Completing the parcel with stops left: "Some drop-offs are not finished yet" (PARCEL_STOPS_PENDING).
- [ ] Fail a stop, then continue: after the last stop the failed items go to the Return to sender flow.
- [ ] **Lost response on a stop action** (airplane mode right after tapping Delivered at this stop, then back online and tap again): the flow moves on without a red "already delivered" error. On the last stop it finishes the parcel.

## 9. City scoping
- [ ] A rider in Addis does not see Hargeisa deliveries or food orders.
- [ ] Forcing an accept across cities (e.g. a stale list after the admin changed the rider's city): "This request is in another city…" and the row is removed.

## 10. Earnings and wallet
- [ ] Addis rider: amounts show as `ETB 1,234.00`. Hargeisa rider: `$12.50`.
- [ ] Earnings screen loads stats, weekly summary and breakdown with no "not found" errors.
- [ ] Cash out in a **USD** wallet: the request is in USD (admin shows a USD withdrawal).
- [ ] Withdrawals on hold (admin toggle): Cash out shows the "Withdrawals on hold" dialog with Contact support. If the API sends `withdrawals_on_hold`, the wallet card shows the banner before tapping.
- [ ] Cash out with airplane mode on, then retry: only **one** withdrawal is created (same idempotency key).
- [ ] COD owed or settlement: Account standing and Settlements open and show the owed amount.

## 11. Arabic / RTL
- [ ] Switch to Arabic: the new screens (Food orders nearby, error messages, camera dialog, withdrawal hold) are in Arabic and laid out RTL. Report any awkward wording, since these Arabic strings are marked for native review.

## 12. Handyman accounts (same app)
- [ ] Available requests load (`/handyman/requests/available`). Accept, Start and Complete work, and Cancel works on an accepted job.
- [ ] "Decline" on an open request only hides it on this phone (no API call). In the detail page it is "Not now".
- [ ] Edit own profile (skills, rate, radius, bio): saves with "Profile updated".
- [ ] Admin build: the handyman detail screen shows the profile (`/admin/handyman/{id}`).

## 13. Going offline with a job assigned by ops
- [ ] Ops assigns an order, then the rider immediately taps offline before the app refreshes: "Finish your current delivery before going offline" (409 DRIVER_ACTIVE_JOB_CONFLICT), and the assigned order appears.

## 14. Regression smoke
- [ ] Chat with the customer on a parcel opens and sends.
- [ ] Notifications inbox opens and marks as read.
- [ ] Driver cancels a parcel before pickup: you see the cancellation message or fee, and the job clears. After pickup you see "Contact support to cancel or return it".
