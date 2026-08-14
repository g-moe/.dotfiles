#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <dispatch/dispatch.h>
#include <pthread.h>

extern void goFanHelperPowerEvent(int event);

enum {
  mactopFanPowerEventSleep = 1,
  mactopFanPowerEventWake = 2,
};

static pthread_mutex_t mactop_fan_power_lock = PTHREAD_MUTEX_INITIALIZER;
static IONotificationPortRef mactop_fan_power_port = NULL;
static io_object_t mactop_fan_power_notifier = IO_OBJECT_NULL;
static io_connect_t mactop_fan_power_connection = IO_OBJECT_NULL;
static dispatch_queue_t mactop_fan_power_queue = NULL;

static void mactopFanPowerCallback(void *refcon, io_service_t service,
                                   natural_t message_type,
                                   void *message_argument) {
  (void)refcon;
  (void)service;

  if (message_type == kIOMessageCanSystemSleep ||
      message_type == kIOMessageSystemWillSleep) {
    pthread_mutex_lock(&mactop_fan_power_lock);
    io_connect_t connection = mactop_fan_power_connection;
    if (connection != IO_OBJECT_NULL) {
      IOAllowPowerChange(connection, (intptr_t)message_argument);
    }
    pthread_mutex_unlock(&mactop_fan_power_lock);
    if (message_type == kIOMessageSystemWillSleep) {
      goFanHelperPowerEvent(mactopFanPowerEventSleep);
    }
    return;
  }

  if (message_type == kIOMessageSystemHasPoweredOn) {
    goFanHelperPowerEvent(mactopFanPowerEventWake);
  }
}

int mactopStartFanPowerNotifications(void) {
  pthread_mutex_lock(&mactop_fan_power_lock);
  if (mactop_fan_power_connection != IO_OBJECT_NULL) {
    pthread_mutex_unlock(&mactop_fan_power_lock);
    return 0;
  }

  IONotificationPortRef port = NULL;
  io_object_t notifier = IO_OBJECT_NULL;
  io_connect_t connection = IORegisterForSystemPower(
      NULL, &port, mactopFanPowerCallback, &notifier);
  if (connection == IO_OBJECT_NULL || port == NULL ||
      notifier == IO_OBJECT_NULL) {
    if (notifier != IO_OBJECT_NULL) {
      IODeregisterForSystemPower(&notifier);
    }
    if (port != NULL) {
      IONotificationPortDestroy(port);
    }
    if (connection != IO_OBJECT_NULL) {
      IOServiceClose(connection);
    }
    pthread_mutex_unlock(&mactop_fan_power_lock);
    return -1;
  }

  dispatch_queue_t queue = dispatch_queue_create(
      "com.mactop.fancontrol.power", DISPATCH_QUEUE_SERIAL);
  if (queue == NULL) {
    IODeregisterForSystemPower(&notifier);
    IONotificationPortDestroy(port);
    IOServiceClose(connection);
    pthread_mutex_unlock(&mactop_fan_power_lock);
    return -1;
  }

  // Keep notifications off the helper's socket-serving goroutines and retain
  // their order on a dedicated serial dispatch queue.
  mactop_fan_power_port = port;
  mactop_fan_power_notifier = notifier;
  mactop_fan_power_connection = connection;
  mactop_fan_power_queue = queue;
  IONotificationPortSetDispatchQueue(port, queue);
  pthread_mutex_unlock(&mactop_fan_power_lock);
  return 0;
}

static void mactopFanPowerQueueDrain(void *context) {
  (void)context;
}

void mactopStopFanPowerNotifications(void) {
  pthread_mutex_lock(&mactop_fan_power_lock);
  IONotificationPortRef port = mactop_fan_power_port;
  io_object_t notifier = mactop_fan_power_notifier;
  io_connect_t connection = mactop_fan_power_connection;
  dispatch_queue_t queue = mactop_fan_power_queue;
  mactop_fan_power_port = NULL;
  mactop_fan_power_notifier = IO_OBJECT_NULL;
  mactop_fan_power_connection = IO_OBJECT_NULL;
  mactop_fan_power_queue = NULL;
  if (port != NULL) {
    IONotificationPortSetDispatchQueue(port, NULL);
  }
  pthread_mutex_unlock(&mactop_fan_power_lock);

  if (queue != NULL) {
    dispatch_sync_f(queue, NULL, mactopFanPowerQueueDrain);
  }
  if (notifier != IO_OBJECT_NULL) {
    IODeregisterForSystemPower(&notifier);
  }
  if (port != NULL) {
    IONotificationPortDestroy(port);
  }
  if (connection != IO_OBJECT_NULL) {
    IOServiceClose(connection);
  }
#if !OS_OBJECT_USE_OBJC
  if (queue != NULL) {
    dispatch_release(queue);
  }
#endif
}
