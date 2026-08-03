# Firestore Database Schema

## Overview

Cloud Firestore is the primary database for the application.

It stores:

- Users
- Conversations
- Messages
- Read status
- Conversation metadata

The schema is optimized for:

- Real-time updates
- Low read costs
- Easy querying
- Scalability

---

# Collections

users/

conversations/

messages/ (subcollection)

---

# Users Collection

Collection

users/{userId}

Fields

uid

String

Firebase Authentication UID

displayName

String

User display name

email

String

Email address

photoUrl

String

Profile picture URL

bio

String

Optional status/bio

createdAt

Timestamp

Account creation date

lastSeen

Timestamp

Last active time

isOnline

Boolean

Used if Presence is implemented

fcmToken

String

Push notification token

---

# Conversations Collection

Collection

conversations/{conversationId}

Fields

id

String

Conversation ID

participants

Array<String>

User IDs

participantNames

Map

Optional cached names

participantPhotos

Map

Optional cached avatars

lastMessage

String

Latest message preview

lastMessageSenderId

String

Sender UID

lastMessageTimestamp

Timestamp

Sorting

lastMessageType

String

text/image

unreadCounts

Map<String,int>

Unread count per user

createdAt

Timestamp

Conversation creation

updatedAt

Timestamp

Last update

---

# Messages Subcollection

Collection

conversations/{conversationId}/messages/{messageId}

Fields

id

String

Message ID

senderId

String

User UID

text

String

Message text

imageUrl

String

Optional image

type

String

text/image

status

String

sending/sent/read

timestamp

Timestamp

Creation time

edited

Boolean

Future support

deleted

Boolean

Future support

---

# Relationships

One User

↓

Many Conversations

One Conversation

↓

Many Messages

---

# Queries

Home Screen

Order conversations by

lastMessageTimestamp DESC

---

Chat Screen

Listen to

messages

ordered by

timestamp ASC

---

Search Users

Query

users

where displayName contains search text

(Implemented using search strategy decided later.)

---

# Indexes

Composite Index

participants

+

lastMessageTimestamp

Descending

---

Composite Index

senderId

+

timestamp

if required

---

# Read Strategy

Conversation List

One stream

Chat Screen

One stream

User Profile

Single document

Search

Query only when user types

---

# Write Strategy

Sending a message

1. Add message document
2. Update conversation metadata
3. Update unread count
4. Trigger notification

---

# Message Status

Allowed values

sending

sent

read

No delivered state in v1.

---

# Future Expansion

Support later

- Group chats
- Reactions
- Replies
- Voice messages
- Documents