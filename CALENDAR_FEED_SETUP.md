# Calendar Feed Integration

## Overview

The SEE ME LIVE app now supports sharing your shows through a stable calendar feed (iCalendar format) that users can add to their favorite calendar apps.

## Features

- **Stable URL**: The calendar feed URL never changes and can be bookmarked indefinitely
- **Auto-sync**: Calendar apps automatically sync new shows as you add them
- **Multiple Calendar Apps**: Works with Apple Calendar, Google Calendar, Outlook, and any app that supports iCalendar format
- **Always Updated**: The feed pulls from your live CloudKit public database

## Implementation

### 1. Calendar Feed URL

The public calendar page builds the feed URL inline from the user ID:

```
https://seemelive.vercel.app/calendar.ics?user=USER_ID
webcal://seemelive.vercel.app/calendar.ics?user=USER_ID
```

### 2. Web Endpoint (calendar.ics)

You need to deploy a serverless function or backend endpoint that:
- Accepts the `user` query parameter
- Queries the CloudKit public database for all shows from that user
- Converts the results to iCalendar (ICS) format
- Returns the response with `Content-Type: text/calendar`

### 3. Web Calendar Page (docs/index.html)

Added a subscription section that appears when users visit the calendar link. It provides buttons to:
- Open in Apple Calendar (via `webcal://` protocol)
- Add to Google Calendar
- Copy the feed link

## Deployment Steps

1. **Deploy the calendar.ics endpoint**:
   - Use the provided `docs/calendar.ics.js` as a template
   - Deploy to Vercel, AWS Lambda, Firebase Functions, or similar
   - Update the feed URL in `docs/index.html` if your endpoint differs

2. **Update the base URL**:
   - Update the `seemelive.vercel.app` host in `docs/index.html` if not using the default domain
   - Ensure the deployment URL matches

3. **Test**:
   - Generate a share link from the app
   - Copy the calendar feed URL
   - Open the calendar link in your browser - you should see the subscription buttons
   - Try adding to a calendar app

## iCalendar Format

The feed returns standard iCalendar format with:
- Event title (show name)
- Date and time
- Venue as location
- Notes/description
- Ticket link as URL property
- Artist role in title/summary
- Unique event ID for deduplication

## Security Considerations

- The calendar feed is **public** - anyone with the user ID can access the shows
- No authentication required (matches the public CloudKit database design)
- Consider rate limiting on the endpoint
- Cache the results to reduce CloudKit queries

## Future Enhancements

- Add filtering (past shows, specific venues)
- Support for custom calendar colors
- Timezone handling
- Recurring show support
- Subscription confirmation/management
