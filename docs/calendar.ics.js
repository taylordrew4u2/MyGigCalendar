/**
 * Calendar ICS Feed Generator
 *
 * Vercel serverless function that turns a performer's public CloudKit shows
 * into an iCalendar feed, so anyone can subscribe in Apple Calendar, Google
 * Calendar, Outlook, etc.
 *
 *   https://seemelive.vercel.app/calendar.ics?user=USER_ID
 */

const CloudKit = require('cloudkit');

const container = CloudKit.configure({
    containers: [{
        containerIdentifier: 'iCloud.comedy.SEE-ME-LIVE',
        apiTokenAuth: {
            // Public read-only token; overridable via env for other deployments.
            apiToken: process.env.CLOUDKIT_API_TOKEN
                || '973fea23642dcde5150a44716fa5b34bc7b1d4502f37851654e926d675fe7132',
        },
        environment: 'production',
    }],
});

/**
 * Fetches a user's public shows and renders them as an iCalendar string.
 */
async function generateCalendarFeed(userID) {
    const db = container.publicCloudDatabase;
    const response = await db.performQuery({
        recordType: 'PublicShow',
        filterBy: [{
            fieldName: 'userID',
            comparator: 'EQUALS',
            fieldValue: { value: userID },
        }],
        sortBy: [{ fieldName: 'date', ascending: true }],
    });

    const events = (response.records || []).flatMap(buildEvent);

    return [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//SEE ME LIVE//Calendar//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        'X-WR-CALNAME:SEE ME LIVE - Upcoming Shows',
        'X-WR-TIMEZONE:UTC',
        'REFRESH-INTERVAL;VALUE=DURATION:PT1H',
        ...events,
        'END:VCALENDAR',
    ].join('\r\n') + '\r\n';
}

/**
 * Builds the VEVENT lines for a single CloudKit record.
 */
function buildEvent(record) {
    const f = record.fields || {};
    const value = (field, fallback) => (f[field] ? f[field].value : fallback);

    const title = value('title', 'Show');
    const role = value('role', '');
    const date = f.date ? new Date(f.date.value) : new Date();

    const summary = role ? `${title} (${role})` : title;

    const lines = [
        'BEGIN:VEVENT',
        `UID:${record.recordID.recordName}@seemelive.local`,
        `DTSTAMP:${formatICSDate(new Date())}`,
        `DTSTART:${formatICSDate(date)}`,
        `SUMMARY:${escapeICS(summary)}`,
    ];

    const venue = value('venue', '');
    const notes = value('notes', '');
    const ticketLink = value('ticketLink', '');

    if (venue) lines.push(`LOCATION:${escapeICS(venue)}`);
    if (notes) lines.push(`DESCRIPTION:${escapeICS(notes)}`);
    if (ticketLink) lines.push(`URL:${ticketLink}`);

    lines.push('END:VEVENT');
    return lines;
}

/**
 * Formats a Date as a UTC iCalendar timestamp: YYYYMMDDTHHMMSSZ.
 */
function formatICSDate(date) {
    return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
}

/**
 * Escapes special characters for ICS text values.
 */
function escapeICS(str) {
    return String(str)
        .replace(/\\/g, '\\\\')
        .replace(/;/g, '\\;')
        .replace(/,/g, '\\,')
        .replace(/\n/g, '\\n');
}

/**
 * Vercel serverless function handler.
 */
module.exports = async (req, res) => {
    const { user } = req.query;

    if (!user) {
        return res.status(400).json({ error: 'Missing user parameter' });
    }

    try {
        const icsContent = await generateCalendarFeed(user);

        res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename="seemelive-${user}.ics"`);
        // Calendar clients poll frequently; cache to ease load on CloudKit.
        res.setHeader('Cache-Control', 'public, max-age=3600');
        res.status(200).send(icsContent);
    } catch (error) {
        console.error('Error generating calendar feed:', error);
        res.status(500).json({ error: 'Failed to generate calendar feed' });
    }
};
