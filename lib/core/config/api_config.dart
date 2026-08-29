import 'package:hudhud_delivery_driver/core/config/app_config.dart';

class ApiConfig {
  /// Reads from `.env` via [AppConfig.baseUrl].
  static String get baseUrl => AppConfig.baseUrl;

  /// Host without `/api` — for storage/avatar URLs.
  static String get originUrl => AppConfig.originUrl;

  // Auth endpoints (relative to BASE_URL which already includes /api)
  static const String registerEndpoint = '/register';
  static const String driverRegisterEndpoint = '/driver/driver/register';
  static const String handymanRegisterEndpoint = '/handyman/register';
  static const String loginEndpoint = '/login';
  static const String sendEmailVerificationEndpoint =
      '/send-email-verification';
  static const String verifyEmailEndpoint = '/verify-email';
  static const String sendPhoneVerificationEndpoint =
      '/send-phone-verification-code';
  static const String verifyPhoneEndpoint = '/verify-phone';
  static const String profileEndpoint = '/profile';
  static const String passwordResetOtpEndpoint = '/password/reset-otp';
  static const String passwordVerifyOtpEndpoint = '/password/verify-otp';
  static const String passwordResendOtpEndpoint = '/password/resend-otp';
  static const String passwordResetWithTokenEndpoint =
      '/password/reset-with-token';

  // Driver profile (authenticated)
  static const String driverProfileEndpoint = '/driver/driver/profile';
  static const String driverApplicationStatusEndpoint =
      '/driver/driver/application-status';

  // Handyman profile (authenticated — returns user + handyman_profile + recent_services)
  static const String handymanAuthProfileEndpoint = '/handyman/profile';

  // Handyman service requests (available list)
  static const String handymanServiceRequestsEndpoint =
      '/handyman/service-requests/available';

  // Handyman earnings (total, weekly, balance, transactions)
  static const String handymanEarningsEndpoint = '/handyman/earnings';

  // Handyman service history (completed services)
  static const String handymanServiceHistoryEndpoint =
      '/handyman/service-history';

  // Driver ride history (paginated)
  static const String driverHistoryEndpoint = '/driver/driver/history';

  // Driver earnings (total, weekly, current_balance, transactions)
  static const String driverEarningsEndpoint = '/driver/driver/earnings';

  // Driver wallet (legacy path — prefer [walletEndpoint])
  static const String driverWalletEndpoint = '/driver/driver/wallet';
  static const String driverWalletTransactionsEndpoint =
      '/driver/driver/wallet/transactions';
  static const String driverWalletWithdrawEndpoint =
      '/driver/driver/wallet/withdraw';

  // Shared customer payment + wallet APIs (driver token)
  static const String paymentMethodsEndpoint = '/payment-methods';
  /// Authenticated registry (eBirr Coop / QPay): GET with type + currency.
  static const String paymentsMethodsEndpoint = '/payments/methods';
  static const String paymentsInitiateEndpoint = '/payments/initiate';
  static String paymentStatusEndpoint(int id) => '/payments/$id/status';
  static String deliveryRetryPaymentEndpoint(int id) =>
      '/services/delivery/$id/retry-payment';
  /// Canonical wallet read (handbook §4.1 / §11).
  static const String walletEndpoint = '/wallet';
  static const String walletTopUpEndpoint = '/wallet/topup';
  static const String walletWithdrawEndpoint = '/wallet/withdraw';
  static const String walletTransferLookupEndpoint =
      '/wallet/transfer/lookup';
  static const String walletTransferEndpoint = '/wallet/transfer';

  // Driver earnings (expanded)
  static const String driverEarningsStatsEndpoint = '/driver/earnings/stats';
  static const String driverEarningsWeeklySummaryEndpoint =
      '/driver/earnings/weekly-summary';
  static const String driverEarningsBreakdownEndpoint =
      '/driver/earnings/breakdown';
  static const String driverPerformanceEndpoint = '/driver/performance';

  // Settlement & account standing
  static const String driverAccountStandingEndpoint = '/driver/account-standing';
  static const String driverSettlementSummaryEndpoint =
      '/driver/settlement/summary';
  static const String driverSettlementsEndpoint = '/driver/settlements';
  static String driverSettlementDetailEndpoint(String id) =>
      '/driver/settlements/$id';
  static String driverDeliveryFinancialPreviewEndpoint(int id) =>
      '/driver/services/delivery/$id/financial-preview';

  // Driver available orders (list of orders ready for pickup / unassigned)
  static const String driverAvailableOrdersEndpoint =
      '/driver/driver/orders/available';

  // Driver services available requests (rides + deliveries)
  static const String driverServicesAvailableRequestsEndpoint =
      '/driver/services/available-requests';

  /// Active job recovery (handbook §7.3).
  static const String driverServicesCurrentStatusEndpoint =
      '/driver/services/current-status';

  /// Authoritative delivery detail for the driver.
  static String driverDeliveryDetailEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId';

  static String driverDeliveryCollectPaymentEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/collect-payment';

  static String driverDeliveryCollectionPaymentStatusEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/collection-payment-status';

  static String driverDeliveryDispatchDiagnosticEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/dispatch-diagnostic';

  static String driverDeliveryArrivePickupEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/arrive-pickup';

  static String driverDeliveryBranchHandoffEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/branch-handoff';

  static String driverDeliveryBranchHandoffResendSmsEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/branch-handoff/resend-sms';

  static String driverDeliveryCancelEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/cancel';

  static String driverDeliveryDeclineEndpoint(int deliveryId) =>
      '/driver/services/delivery/$deliveryId/decline';

  static String driverRideAcceptEndpoint(int rideId) =>
      '/driver/services/ride/$rideId/accept';

  static String driverRideCancelEndpoint(int rideId) =>
      '/driver/services/ride/$rideId/cancel';

  static String driverRideDeclineEndpoint(int rideId) =>
      '/driver/services/ride/$rideId/decline';

  static const String driverRideStartEndpoint = '/driver/services/ride/start';
  static const String driverRideCompleteEndpoint =
      '/driver/services/ride/complete';

  // Driver profile documents (multipart upload)
  static const String driverProfileDocumentsEndpoint =
      '/driver/profile/documents';

  // Driver availability (go online/offline)
  static const String driverAvailabilityEndpoint = '/driver/availability';

  // FCM device token registration
  static const String deviceTokenEndpoint = '/fcm/token';

  /// Driver location update (preferred: POST with recorded_at + source).
  static const String driverUpdateLocationEndpoint = '/driver/update-location';

  // Driver location update (full: active ride)
  static const String driverLocationEndpoint = '/driver/location';

  // Driver location (simple: no active ride) — latitude, longitude, order_id
  static const String driverDriverLocationEndpoint = '/driver/driver/location';

  // Chat — package delivery (courier)
  static const String chatPackageDeliveryConversations =
      '/chat/package-delivery/conversations';
  static const String chatPackageDeliveryUnreadCount =
      '/chat/package-delivery/unread-count';
  static String chatPackageDeliveryConversation(int deliveryId) =>
      '/chat/package-delivery/$deliveryId/conversation';
  static String chatPackageDeliveryMessages(int deliveryId) =>
      '/chat/package-delivery/$deliveryId/messages';
  static String chatPackageDeliveryMarkRead(int deliveryId) =>
      '/chat/package-delivery/$deliveryId/mark-read';

  // Chat — general
  static const String chatSupport = '/chat/support';
  static String chatConversation(int id) => '/chat/conversations/$id';
  static String chatConversationMessages(int id) =>
      '/chat/conversations/$id/messages';
  static String chatConversationRead(int id) =>
      '/chat/conversations/$id/read';

  // In-app notifications inbox
  static const String notificationsEndpoint = '/notifications';
  static const String notificationsReadEndpoint = '/notifications/read';
  static const String notificationsReadAllEndpoint = '/notifications/read-all';
  static String notificationByIdEndpoint(String id) => '/notifications/$id';

  // Full URLs
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get driverRegisterUrl => '$baseUrl$driverRegisterEndpoint';
  static String get handymanRegisterUrl => '$baseUrl$handymanRegisterEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get sendEmailVerificationUrl =>
      '$baseUrl$sendEmailVerificationEndpoint';
  static String get verifyEmailUrl => '$baseUrl$verifyEmailEndpoint';
  static String get sendPhoneVerificationUrl =>
      '$baseUrl$sendPhoneVerificationEndpoint';
  static String get verifyPhoneUrl => '$baseUrl$verifyPhoneEndpoint';
  static String get passwordResetOtpUrl => '$baseUrl$passwordResetOtpEndpoint';
  static String get passwordVerifyOtpUrl =>
      '$baseUrl$passwordVerifyOtpEndpoint';
  static String get passwordResendOtpUrl =>
      '$baseUrl$passwordResendOtpEndpoint';
  static String get passwordResetWithTokenUrl =>
      '$baseUrl$passwordResetWithTokenEndpoint';

  // Admin endpoints (list users by type, get/update user, handyman profile)
  static const String adminUsersEndpoint = '/admin/users';
  static const String userByIdEndpoint = '/users';
  static const String handymanProfileEndpoint = '/handyman-profile';

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
