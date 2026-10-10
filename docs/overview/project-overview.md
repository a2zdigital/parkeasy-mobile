# Project Overview

## What it is

ParkEasy is a two-sided parking marketplace. Owners list parking facilities; customers find one nearby, see the price, book by the hour or the day, and pay online or at the facility. The pilot is a single city in India, in INR.

This repository is the mobile app. The API and the admin web dashboard are separate repositories. **The API holds every business rule**; the app shows what the API says and sends what the user chose.

## Who uses the app

| Role | What they do in the app |
|---|---|
| Customer | Search near a location, view a facility, check availability and price, book, pay, view and cancel bookings, read notifications |
| Owner | Apply to become an owner, create and edit facilities (spaces, rates, hours), approve or reject requests, check customers in and out, record payment taken at the facility, see earnings |

One person can be both. Administrators use the web dashboard, not this app.

## Scope of the first version

In: phone and OTP sign-in · search and facility details · availability and quote · booking and cancellation · online payment (Razorpay) and pay at the facility · booking history · in-app notifications · owner onboarding, facilities, bookings, gate and earnings.

Not in the first version: push notifications · facility photos · reviews, favourites, saved vehicles · offline booking · languages other than English · tablets as a designed layout.

## What the API does not offer yet

These limit the app until the API team delivers them.

| Missing | Effect on the app |
|---|---|
| Real SMS codes | Only the fixed development code works, and only against a local API |
| Staging server | No shared URL; each developer runs the API locally |
| Push and device-token registration | Poll the notification endpoints |
| Facility photos | Design screens to work without images |
| Razorpay verified in test mode | Use the API's simulated payment locally |

## Platforms

Android and iOS phones, portrait. Minimum OS versions are an open decision (MD-04).
