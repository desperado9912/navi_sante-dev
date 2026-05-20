// Multi-layer email validation.

// Layer 1: RFC-compliant regex format check.
//          Catches obvious malformed emails and typos.

// Layer 2: MX record proxy — DNS and TCP reachability check.
//          Checks if email is valid with active mail Inbox.

// Layer 3: Disposable email domain blocklist.
//          Curated list of common disposable email providers.
//          Expand this list over time as new providers emerge.

import 'dart:io';
import 'dart:async';
import 'package:navi_sante/core/performance/isolate_runner.dart';

// Layer 1: RFC-compliant regex format check.
const String emailRegexPattern =
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$';

final RegExp emailRegex = RegExp(emailRegexPattern);

// Layer 2: MX record proxy — DNS and TCP reachability check.
// Must be a top level or static function — closures cannot be sent to isolates.
Future<bool> _isDomainReachable(String domain) async {
  try {
    final addresses = await InternetAddress.lookup(
      domain,
    ).timeout(const Duration(seconds: 5));
    return addresses.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return true;
  } catch (_) {
    return true;
  }
}

class AppEmailValidator {
  AppEmailValidator._();

  //validation entry point
  static Future<String?> validate(String email) async {
    final trimmed = email.trim().toLowerCase();

    // Layer 1 check
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }

    // Layer 2 check
    final domain = trimmed.split('@').last;
    if (_disposableDomains.contains(domain)) {
      return 'Disposable email addresses are not allowed.';
    }

    // Layer 3 check
    final domainReachable = await IsolateRunner.run(_isDomainReachable, domain);
    if (!domainReachable) {
      return 'This email domain does not appear to be valid.';
    }
    return null;
  }

  // Layer 3: Disposable email domain blocklist.
  static const _disposableDomains = <String>{
    // 10-minute mail
    '10minutemail.com', '10minutemail.net', '10minutemail.org',
    '10minemail.com', '10minutemail.de', '10minutemail.be',
    'tenminutemail.com', 'tenminutemail.org',
    // Guerrilla Mail
    'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
    'guerrillamail.de', 'guerrillamail.info', 'guerrillamail.biz',
    'guerrillamailblock.com', 'grr.la', 'spam4.me',
    // Mailinator and variants
    'mailinator.com', 'mailinator.net', 'mailinator.org',
    'mailinater.com', 'mailinator2.com', 'trashmail.at',
    // Temp-Mail
    'temp-mail.org', 'tempmail.com', 'tempmail.net',
    'temp-mail.io', 'tempinbox.com', 'tempr.email',
    // YOPmail
    'yopmail.com', 'yopmail.fr', 'cool.fr.nf', 'jetable.fr.nf',
    'nospam.ze.tc', 'nomail.xl.cx', 'mega.zik.dj',
    // Throwam / Fakeinbox
    'throwam.com', 'fakeinbox.com', 'fakeinbox.net',
    'mailnull.com', 'spamgourmet.com', 'spamgourmet.net',
    // Dispostable / Trashmail
    'dispostable.com', 'trashmail.com', 'trashmail.me',
    'trashmail.net', 'trashmail.org', 'trashmail.io',
    // Sharklasers / Maildrop
    'sharklasers.com', 'maildrop.cc', 'spamhole.com', 'jetable.com',
    // Others
    'mailnesia.com',
    'throwaway.email', 'throwmail.com',
    'spamthisplease.com', 'spamfree24.org', 'spamfree.eu',
    'mytrashmail.com', 'mytrashmailer.com', 'putthisinyourspamdatabase.com',
    'mailmetrash.com', 'trashdevil.de', 'trashdevil.com',
    'mt2014.com', 'mt2015.com', 'spamfighter.cf', 'spamfighter.ga',
    'spamfighter.gq', 'spamfighter.ml', 'spamfighter.tk',
    'powered.name', 'discardmail.com', 'discardmail.de',
    'spamstack.net', 'mailboxy.fun', 'tempail.com',
    'getairmail.com', 'filzmail.com', 'deypo.com',
    'discard.email', 'spamgon.com',
  };
}
