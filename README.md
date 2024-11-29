# Spamhammer - Fight Mastodon spam the preposterous way

Summary: Mastodon has few tools for automatedly fighting spam and abuse so I gave up and made one.

We've been swamped with a flood of spam for the last few months. Some losers are creating hundreds or thousands of accounts on undermoderated servers and pestering the whole fediverse with junk. Mastodon itself provides no mechanism for admins to reject statuses that contain certain strings, even though many people have begged for this over the years. And while I could learn enough Ruby on Rails to implement such a feature myself, I'm not confident that it would be accepted into the main project and I don't want to maintain a fork.

What I _do_ have is root-level access to my instance's database, enough SQL knowledge to be dangerous, and a willingness to break things and see what happens. I put all that in a blender and some working code came out the other side.

What you're looking at is a PostgreSQL [check constraint](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS) that applies [a function](https://www.postgresql.org/docs/current/plpgsql-overview.html#PLPGSQL-ADVANTAGES) I wrote to every status insert into the database, and rejects ones that contain text I don't ever want to store on my instance. If I try to post a toot that contains such text, I get a little "500" popup in the corner of my screen and it doesn't get sent. I'm not sure what happens if another server tries to send us a toot with that text. I'm guessing the API returns a 500, too, and it fills up their outbound queue with retries. I honestly couldn't care less. Don't send us spam, yo.

Before you apply this on your own server, _read the giant warning at the top_. If you don't, and you mess around with this without following the advice, you're going to be a very sad camper next time you try to restore your database. Don't panic, though. This uses normal, built-in PostgreSQL features in the normal, not-"clever" way they're meant to be used. The risk isn't to this database check specifically, but to _all_ PostgreSQL check constraints that call user-defined functions. Like so many other database features, it's something to learn, understand, and respect.

A little nervous? Good. You're about to tell your database to reject otherwise valid data that the server tries to insert into it. Don't do that unless you're comfortable with the idea. Sure would be nice if there were an approved way to filter toots so we didn't have to resort to drastic measures, but if you've read along this far, you're probably as annoyed by all this as I am and ready to cry havoc and loose the hounds of YOLO.

And with that, let's YOLO.

## Installation

Run [spamhammer.sql](spamhammer.sql) on your server. I'm not going to tell you how to do this. If you're not certain how to do that, you probably should not be making this change. I don't mean to be an elitist jerk about it, I promise! It's just that I don't want to help anyone shoot themselves in the foot.

## Status

We've been running this on [Free Radical](https://freeradical.zone/) since early October 2024 and nothing's caught on fire yet. We have many fewer spam reports now than we'd had leading up to this.