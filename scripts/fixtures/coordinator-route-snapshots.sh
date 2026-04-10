#!/usr/bin/env bash

# Snapshot fixture for coordinator route enums.
# Intentionally update these values only when route-shape changes are expected.

SNAPSHOT_DiscoverRoute="djDetail eventCreate eventDetail eventEdit festivalDetail labelDetail learnFestivalCreate learnFestivalEdit newsDetail newsPublish searchInput searchResults setCreate setDetail setEdit"
SNAPSHOT_CircleRoute="djDetail eventDetail idCreate postCreate postDetail postEdit ratingEventCreate ratingEventDetail ratingEventImportFromEvent ratingUnitCreate squadProfile userProfile"
SNAPSHOT_MessagesRoute="alertCategory conversation userProfile"
SNAPSHOT_MessagesModalRoute="squadProfile"
SNAPSHOT_ProfileRoute="avatarFullscreen conversation djDetail editEvent editProfile editRatingEvent editRatingUnit editSet eventDetail followList myCheckins myPublishes postDetail publishEvent settings squadProfile uploadSet userProfile"
