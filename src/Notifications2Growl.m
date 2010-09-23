/* Notifications2Growl.m - Implementation of the destop notification spec for Growl
 *
 * Copyright (C) 2010 Eric Le Lay <elelay@macports.org>
 * adapted from notification-daemon-0.4.0/src/daemon/daemon.c
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
#import <Foundation/Foundation.h>
#import <Growl/Growl.h>

#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>

#include <dbus/dbus.h>
#include <dbus/dbus-glib.h>
#include <glib/gi18n.h>
#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>

#import "Notifications2Growl.h"
#import "notificationdaemon-dbus-glue.h"

#define MY_NOTIFICATION XSTR("forwarded notification")

// {{{ get icon data
#define IMAGE_SIZE 48

static GdkPixbuf*
_notify_daemon_process_icon_data(GValue *icon_data)
{
	const guchar *data = NULL;
	gboolean has_alpha;
	int bits_per_sample;
	int width;
	int height;
	int rowstride;
	int n_channels;
	gsize expected_len;
	GdkPixbuf *pixbuf = NULL;
	GValueArray *image_struct;
	GValue *value;
	GArray *tmp_array;
	GType struct_type;

	struct_type = dbus_g_type_get_struct(
		"GValueArray",
		G_TYPE_INT,
		G_TYPE_INT,
		G_TYPE_INT,
		G_TYPE_BOOLEAN,
		G_TYPE_INT,
		G_TYPE_INT,
		dbus_g_type_get_collection("GArray", G_TYPE_UCHAR),
		G_TYPE_INVALID);

	if (!G_VALUE_HOLDS(icon_data, struct_type))
	{
		g_warning("_notify_daemon_process_icon_data expected a "
				  "GValue of type GValueArray");
		return pixbuf;
	}

	image_struct = (GValueArray *)g_value_get_boxed(icon_data);
	value = g_value_array_get_nth(image_struct, 0);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected position "
				  "0 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_INT))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 0 of the GValueArray to be of type int");
		return pixbuf;
	}

	width = g_value_get_int(value);
	value = g_value_array_get_nth(image_struct, 1);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 1 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_INT))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 1 of the GValueArray to be of type int");
		return pixbuf;
	}

	height = g_value_get_int(value);
	value = g_value_array_get_nth(image_struct, 2);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 2 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_INT))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 2 of the GValueArray to be of type int");
		return pixbuf;
	}

	rowstride = g_value_get_int(value);
	value = g_value_array_get_nth(image_struct, 3);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 3 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_BOOLEAN))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 3 of the GValueArray to be of type gboolean");
		return pixbuf;
	}

	has_alpha = g_value_get_boolean(value);
	value = g_value_array_get_nth(image_struct, 4);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 4 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_INT))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 4 of the GValueArray to be of type int");
		return pixbuf;
	}

	bits_per_sample = g_value_get_int(value);
	value = g_value_array_get_nth(image_struct, 5);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 5 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value, G_TYPE_INT))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 5 of the GValueArray to be of type int");
		return pixbuf;
	}

	n_channels = g_value_get_int(value);
	value = g_value_array_get_nth(image_struct, 6);

	if (value == NULL)
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 6 of the GValueArray to exist");
		return pixbuf;
	}

	if (!G_VALUE_HOLDS(value,
					   dbus_g_type_get_collection("GArray", G_TYPE_UCHAR)))
	{
		g_warning("_notify_daemon_process_icon_data expected "
				  "position 6 of the GValueArray to be of type GArray");
		return pixbuf;
	}

	tmp_array = (GArray *)g_value_get_boxed(value);
	expected_len = (height - 1) * rowstride + width *
	               ((n_channels * bits_per_sample + 7) / 8);

	if (expected_len != tmp_array->len)
	{
		g_warning("_notify_daemon_process_icon_data expected image "
				  "data to be of length %" G_GSIZE_FORMAT " but got a "
				  "length of %u",
				  expected_len, tmp_array->len);
		return pixbuf;
	}

	data = (guchar *)g_memdup(tmp_array->data, tmp_array->len);
	pixbuf = gdk_pixbuf_new_from_data(data, GDK_COLORSPACE_RGB, has_alpha,
									  bits_per_sample, width, height,
									  rowstride,
									  (GdkPixbufDestroyNotify)g_free,
									  NULL);
	return pixbuf;
}
	
static
NSData* getImageData(const gchar *icon,
					 GHashTable *hints)
{
	NSData* imgData = NULL;
	/* check for icon_data if icon == "" */
	GdkPixbuf *pixbuf = NULL;
	if (*icon == '\0')
	{
		GValue *data = (GValue *)g_hash_table_lookup(hints, "icon_data");
		if (data)
		{
			pixbuf = _notify_daemon_process_icon_data(data);
		}
	}
	else
	{
		if (!strncmp(icon, "file://", 7) || *icon == '/')
		{
			if (!strncmp(icon, "file://", 7))
				icon += 7;

			/* Load file */
			pixbuf = gdk_pixbuf_new_from_file(icon, NULL);
		}
		else
		{
			/* Load icon theme icon */
			GtkIconTheme *theme = gtk_icon_theme_get_default();
			GtkIconInfo *icon_info =
				gtk_icon_theme_lookup_icon(theme, icon, IMAGE_SIZE,
										   GTK_ICON_LOOKUP_USE_BUILTIN);

			if (icon_info != NULL)
			{
				gint icon_size = MIN(IMAGE_SIZE,
									 gtk_icon_info_get_base_size(icon_info));

				if (icon_size == 0)
					icon_size = IMAGE_SIZE;

				pixbuf = gtk_icon_theme_load_icon(theme, icon, icon_size,
												  GTK_ICON_LOOKUP_USE_BUILTIN,
												  NULL);

				gtk_icon_info_free(icon_info);
			}

			if (pixbuf == NULL)
			{
				/* Well... maybe this is a file afterall. */
				pixbuf = gdk_pixbuf_new_from_file(icon, NULL);
			}
		}

		if (pixbuf != NULL)
		{
			gchar* buffer = NULL;
			gsize buffer_size = 0;
			GError* error = NULL;
			if(gdk_pixbuf_save_to_bufferv(pixbuf,
                                             &buffer,
                                             &buffer_size,
                                             "png",
                                             NULL,
                                             NULL,
                                             &error))
            {
            	// FIXME: not too sure about type conversion between gsize and NS(U)Integer...
            	imgData = [NSData dataWithBytes:buffer length:buffer_size];
            	free(buffer);
            }
            else
            {
            	printf("gdk_pixbuf_save_to_bufferv error: %s %i %s\n",g_quark_to_string(error->domain),error->code,error->message);
            	free(error);
            }
			g_object_unref(G_OBJECT(pixbuf));
		}
	}
	return imgData;
}
// }}}

static DBusConnection *dbus_conn = NULL;
// FIXME: the original code stored it in the windows. Why ?
static NotifyDaemon* mydaemon = NULL;

// {{{ NotifyDaemon object

// NotifyTimeout stores the id and source of a notification
typedef struct
{
	// id of notification
	guint id;
	// dbus source of notification
	gchar* sender;
} NotifyTimeout;

struct _NotifyDaemonPrivate
{
	guint next_id;
	GHashTable *notification_hash;
};

static void notify_daemon_finalize(GObject *object);
static void _close_notification(NotifyDaemon *daemon, guint id,
								NotifydClosedReason reason);

G_DEFINE_TYPE(NotifyDaemon, notify_daemon, G_TYPE_OBJECT);


static void
notify_daemon_class_init(NotifyDaemonClass *daemon_class)
{
	GObjectClass *object_class = G_OBJECT_CLASS(daemon_class);

	object_class->finalize = notify_daemon_finalize;

	g_type_class_add_private(daemon_class, sizeof(NotifyDaemonPrivate));
}

static void
notify_daemon_init(NotifyDaemon *daemon)
{
	daemon->priv = G_TYPE_INSTANCE_GET_PRIVATE(daemon, NOTIFY_TYPE_DAEMON,
											   NotifyDaemonPrivate);

	daemon->priv->next_id = 1;

	daemon->priv->notification_hash =
		g_hash_table_new_full(g_int_hash, g_int_equal, g_free,
							  g_free);
}

static void
notify_daemon_finalize(GObject *object)
{
	NotifyDaemon *daemon       = NOTIFY_DAEMON(object);
	GObjectClass *parent_class = G_OBJECT_CLASS(notify_daemon_parent_class);

	g_hash_table_destroy(daemon->priv->notification_hash);
	g_free(daemon->priv);

	if (parent_class->finalize != NULL)
		parent_class->finalize(object);
}

GQuark
notify_daemon_error_quark(void)
{
	static GQuark q = 0;

	if (q == 0)
		q = g_quark_from_static_string("notification-daemon-error-quark");

	return q;
}
// }}}

// {{{ create and close notifications
static DBusMessage *
create_signal(NotifyTimeout* nt, const char *signal_name)
{
	guint id = nt->id;
	gchar *dest = nt->sender;
	DBusMessage *message;

	g_assert(dest != NULL);

	message = dbus_message_new_signal("/org/freedesktop/Notifications",
									  "org.freedesktop.Notifications",
									  signal_name);

	dbus_message_set_destination(message, dest);
	dbus_message_append_args(message,
							 DBUS_TYPE_UINT32, &id,
							 DBUS_TYPE_INVALID);
	return message;
}

static void
_action_invoked_cb(NotifyDaemon *daemon, guint id, const char *key)
{
	DBusMessage *message;
	NotifyDaemonPrivate *priv = daemon->priv;
	NotifyTimeout *nt;

	nt = (NotifyTimeout *)g_hash_table_lookup(priv->notification_hash, &id);

	if (nt != NULL)
	{
		if(nt->sender)
		{
			message = create_signal(nt, "ActionInvoked");
			dbus_message_append_args(message,
									 DBUS_TYPE_STRING, &key,
									 DBUS_TYPE_INVALID);
		
			dbus_connection_send(dbus_conn, message, NULL);
			dbus_message_unref(message);
		}
	
		_close_notification(daemon, id, NOTIFYD_CLOSED_USER);
	}
}

static void
_emit_closed_signal(NotifyTimeout* nt, NotifydClosedReason reason)
{
	DBusMessage *message = create_signal(nt, "NotificationClosed");
	dbus_message_append_args(message,
							 DBUS_TYPE_UINT32, &reason,
							 DBUS_TYPE_INVALID);
	dbus_connection_send(dbus_conn, message, NULL);
	dbus_message_unref(message);
}

static void
_close_notification(NotifyDaemon *daemon, guint id,
					NotifydClosedReason reason)
{
	NotifyDaemonPrivate *priv = daemon->priv;
	NotifyTimeout *nt;

	nt = (NotifyTimeout *)g_hash_table_lookup(priv->notification_hash, &id);

	if (nt != NULL)
	{
		if(reason == NOTIFYD_CLOSED_API){
			g_warning("can't close Growl's notification");
		}
		if(nt->sender){
			_emit_closed_signal(nt, reason);
		}

		g_hash_table_remove(priv->notification_hash, &id);
	}
}
static NotifyTimeout *
_store_notification(NotifyDaemon *daemon)
{
	NotifyDaemonPrivate *priv = daemon->priv;
	NotifyTimeout *nt;
	guint id = 0;

	// when guint is exhausted and long-standing notifications are still there,
	// can't reassign an existing id
	do
	{
		id = priv->next_id;

		if (id != UINT_MAX)
			priv->next_id++;
		else
			priv->next_id = 1;

		if (g_hash_table_lookup(priv->notification_hash, &id) != NULL)
			id = 0;

	} while (id == 0);

	nt = g_new0(NotifyTimeout, 1);
	nt->id = id;

	g_hash_table_insert(priv->notification_hash,
						g_memdup(&id, sizeof(guint)), nt);

	return nt;
}
// }}}

// {{{ dbus handlers
gboolean
notify_daemon_notify_handler(NotifyDaemon *daemon,
							 const gchar *app_name,
							 guint replaces_id,
							 const gchar *icon,
							 const gchar *summary,
							 const gchar *body,
							 gchar **actions,
							 GHashTable *hints,
							 int timeout, DBusGMethodInvocation *context)
{
	NotifyDaemonPrivate *priv = daemon->priv;
	NotifyTimeout* nt = NULL;
	guint return_id = 1;
	gint i;
	gchar *sender;
	gboolean wantsActionCallback = FALSE;
	
	printf("%s: %s\n",app_name,summary);
	
	
	if (replaces_id > 0)
	{
		nt = (NotifyTimeout *)g_hash_table_lookup(priv->notification_hash,
												  &replaces_id);

		if (nt == NULL)
		{
			g_warning("unknown action id sent by client:%i",replaces_id);
			replaces_id = 0;
		}
	}
	
	if (replaces_id == 0)
	{
		nt = _store_notification(daemon);
		return_id = nt->id;
	}
	else
	{
		return_id = replaces_id;
	}
	
	NSString* summary_str = [[NSString alloc] initWithUTF8String:summary];
	
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
	
	[dictionary setObject: summary_str forKey: GROWL_NOTIFICATION_TITLE];
	if(body){
		NSString* body_str = [[NSString alloc] initWithUTF8String:body];
		[dictionary setObject: body_str forKey: GROWL_NOTIFICATION_DESCRIPTION];
	}
	
	// default action handling
	/* set up action buttons */
	for (i = 0; actions[i] != NULL; i += 2)
	{
		gchar *l = actions[i + 1];

		if (l == NULL)
		{
			g_warning("Label not found for action %s. "
					  "The protocol specifies that a label must "
					  "follow an action in the actions array", actions[i]);

			break;
		}

		if (strcasecmp(actions[i], "default"))
		{
			printf("GOT A DEFAULT ACTION CALLBACK\n");
			wantsActionCallback = TRUE;
		}
		else
		{
			printf("GOT A %s ACTION CALLBACK (%s)\n",actions[i],l);
		}
	}
	
	// icon handling
	NSData* imgData = getImageData(icon,hints);
	if(imgData)
	{
			[dictionary setObject: imgData forKey: GROWL_NOTIFICATION_ICON];
	}	
	
	if(wantsActionCallback)
	{
		sender = dbus_g_method_get_sender(context);
		nt->sender = sender;
	}
	else
	{
		nt->sender = NULL;
	}
	
	
	[dictionary setObject: MY_NOTIFICATION forKey:GROWL_NOTIFICATION_NAME];
	
	// want to be notifed anyway !
	NSNumber* num = [NSNumber numberWithInt: return_id];
	[dictionary setObject: [num autorelease]  forKey:GROWL_NOTIFICATION_CLICK_CONTEXT];
	
	
	
	[GrowlApplicationBridge notifyWithDictionary: dictionary];
	
	[dictionary release];
	
	dbus_g_method_return(context, return_id);
	return TRUE;
}

gboolean
notify_daemon_close_notification_handler(NotifyDaemon *daemon,
										 guint id, GError **error)
{
	if (id == 0)
	{
		g_set_error(error, notify_daemon_error_quark(), 100,
					_("%u is not a valid notification ID"), id);
		return FALSE;
	} else {
		printf("client wants to close %u\n",id);
		_close_notification(daemon, id, NOTIFYD_CLOSED_API);
		return TRUE;
	}
}

gboolean
notify_daemon_get_capabilities(NotifyDaemon *daemon, char ***caps)
{
	*caps = g_new0(char *, 4);

	(*caps)[0] = g_strdup("actions");
	(*caps)[1] = g_strdup("body");
	// growl doesn't support that !
/*	(*caps)[2] = g_strdup("body-hyperlinks");
	(*caps)[3] = g_strdup("body-markup");*/
	(*caps)[2] = g_strdup("icon-static");
	(*caps)[3] = NULL;

	return TRUE;
}

gboolean
notify_daemon_get_server_information(NotifyDaemon *daemon,
									 char **out_name,
									 char **out_vendor,
									 char **out_version,
									 char **out_spec_ver)
{
	*out_name     = g_strdup("Notifications2Growl");
	*out_vendor   = g_strdup("Eric Le Lay");
	*out_version  = g_strdup("0.1");
	*out_spec_ver = g_strdup("1.0");

	return TRUE;
}
// }}}

// {{{ Growl delegate implementation
void print( NSDictionary *map ) {
    NSEnumerator *enumerator = [map keyEnumerator];
    id key;

    while ( key = [enumerator nextObject] ) {
        printf( "%s => %s\n",
                [[key description] cString],
                [[[map objectForKey: key] description] cString] );
    }
}

#define MY_APP_NAME	XSTR("ObjcServer")
#define MY_APP_ID	XSTR("N2GR")

@implementation GrowlController


- (NSDictionary *) registrationDictionaryForGrowl {
	NSArray* notifs = [[NSArray alloc] initWithObjects:
			                    MY_NOTIFICATION,nil];
	NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
			notifs,GROWL_NOTIFICATIONS_ALL,
			notifs,GROWL_NOTIFICATIONS_DEFAULT,
			MY_APP_NAME,GROWL_APP_NAME,
			MY_APP_ID,GROWL_APP_ID,
			nil];
	//print(dictionary);
	return [dictionary autorelease];
}
- (void) growlIsReady {
	printf("Growl is READY\n");
}

- (void) growlNotificationWasClicked:(id)clickContext{
	guint idnum = [clickContext unsignedIntValue];
	printf("Notification %u was clicked\n",idnum);
	_action_invoked_cb(mydaemon,idnum,"default");
}
- (void) growlNotificationTimedOut:(id)clickContext{
	guint idnum = [clickContext unsignedIntValue];
	printf("Notification %u timeout\n",idnum);
	_close_notification(mydaemon, idnum, NOTIFYD_CLOSED_EXPIRED);
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender{
	NSLog(@"should terminate !");
	return NSTerminateNow;
}

@end

// }}}

// {{{ main()
int main (int argc, char * argv[]) {
	NSAutoreleasePool * pool;
	DBusGConnection *connection;
	DBusGProxy *bus_proxy;
	GError *error;
	guint request_name_result;
	
	DBusError error2;

	// {{{ init growl
    pool = [[NSAutoreleasePool alloc] init];

    GrowlController *growl = [[GrowlController alloc] init];
    [GrowlApplicationBridge setGrowlDelegate:growl];
    // }}}
    
    // {{{ init dbus
	gtk_init(&argc, &argv);


	dbus_error_init (&error2);
	
	g_thread_init (NULL); dbus_g_thread_init ();
	g_type_init ();
	
	g_log_set_always_fatal(G_LOG_LEVEL_ERROR | G_LOG_LEVEL_CRITICAL);
	
	error = NULL;

	connection = dbus_g_bus_get(DBUS_BUS_SESSION, &error);

	if (connection == NULL)
	{
		g_printerr("Failed to open connection to bus: %s\n",
			error->message);
		g_error_free(error);
		exit(1);
	}
	
	dbus_conn = dbus_g_connection_get_connection(connection);
	
	dbus_g_object_type_install_info(NOTIFY_TYPE_DAEMON,
		&dbus_glib_notification_daemon_object_info);
	
	bus_proxy = dbus_g_proxy_new_for_name(connection,
										  "org.freedesktop.DBus",
										  "/org/freedesktop/DBus",
										  "org.freedesktop.DBus");

	if (!dbus_g_proxy_call(bus_proxy, "RequestName", &error,
						   G_TYPE_STRING, "org.freedesktop.Notifications",
						   G_TYPE_UINT, 0,
						   G_TYPE_INVALID,
						   G_TYPE_UINT, &request_name_result,
						   G_TYPE_INVALID))
	{
		g_error("Could not aquire name: %s", error->message);
	}

	mydaemon = (NotifyDaemon*) g_object_new(NOTIFY_TYPE_DAEMON, NULL);

	dbus_g_connection_register_g_object(connection,
										"/org/freedesktop/Notifications",
										G_OBJECT(mydaemon));
	// }}}
	
	// {{{ run main loop
	// running the gtk main loop makes the callbacks available
	// but it adds the application to the doc !
	gtk_main();
	// }}}
	
	// release resources
    [pool release];

	return 0;
} //}}}