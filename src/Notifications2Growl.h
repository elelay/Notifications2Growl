/*
 * Notifications2Growl.h - Implementation of the destop notification spec for Growl
 *
 * Copyright (C) 2010 Eric Lay <elelay@macports.org>
 * adapted from notification-daemon-0.4.0/src/daemon/daemon.h
 * Copyright (C) 2006 Christian Hammond <chipx86@chipx86.com>
 * Copyright (C) 2005 John (J5) Palmieri <johnp@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 */
#ifndef NOTIFY_DAEMON_H
#define NOTIFY_DAEMON_H

#include <glib.h>
#include <glib-object.h>

#include <dbus/dbus-glib.h>
#include <dbus/dbus-glib-lowlevel.h>

#define NOTIFY_TYPE_DAEMON (notify_daemon_get_type())
#define NOTIFY_DAEMON(obj) \
	(G_TYPE_CHECK_INSTANCE_CAST ((obj), NOTIFY_TYPE_DAEMON, NotifyDaemon))

enum
{
	URGENCY_LOW,
	URGENCY_NORMAL,
	URGENCY_CRITICAL
};

typedef enum
{
	NOTIFYD_CLOSED_EXPIRED = 1,
	NOTIFYD_CLOSED_USER = 2,
	NOTIFYD_CLOSED_API = 3,
	NOTIFYD_CLOSED_RESERVED = 4

} NotifydClosedReason;

typedef struct _NotifyDaemon        NotifyDaemon;
typedef struct _NotifyDaemonClass   NotifyDaemonClass;
typedef struct _NotifyDaemonPrivate NotifyDaemonPrivate;

struct _NotifyDaemon
{
	GObject parent;

	/*< private > */
	NotifyDaemonPrivate *priv;
};

struct _NotifyDaemonClass
{
	GObjectClass parent_class;
};

G_BEGIN_DECLS

GType notify_daemon_get_type(void);

GQuark notify_daemon_error_quark(void);

gboolean notify_daemon_notify_handler(NotifyDaemon *daemon,
									  const gchar *app_name,
									  guint id,
									  const gchar *icon,
									  const gchar *summary,
									  const gchar *body,
									  gchar **actions,
									  GHashTable *hints,
									  int timeout,
									  DBusGMethodInvocation *context);

gboolean notify_daemon_close_notification_handler(NotifyDaemon *daemon,
												  guint id, GError **error);

gboolean notify_daemon_get_capabilities(NotifyDaemon *daemon,
										char ***out_caps);

gboolean notify_daemon_get_server_information(NotifyDaemon *daemon,
											  char **out_name,
											  char **out_vendor,
											  char **out_version,
											  char **out_spec_ver);

G_END_DECLS

#import <Foundation/NSObject.h>
@interface GrowlController : NSObject <GrowlApplicationBridgeDelegate> {
}
- (NSDictionary *) registrationDictionaryForGrowl;
- (void) growlIsReady;
- (void) growlNotificationWasClicked:(id)clickContext;
- (void) growlNotificationTimedOut:(id)clickContext;
@end

#endif /* NOTIFY_DAEMON_H */
