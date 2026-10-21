/// Page web de la politique de confidentialité, publiée pour Google Play.
/// Elle ne charge aucune ressource externe.
library;

import 'privacy.dart';

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Échappe le texte, puis transforme l'adresse de contact en lien.
String _paragraph(String text) =>
    _escape(text).replaceAll(contactEmail, '<a href="mailto:$contactEmail">$contactEmail</a>');

String renderPrivacyPage() {
  final sections = StringBuffer();
  for (final section in privacySections) {
    sections
      ..writeln('    <section>')
      ..writeln('      <h2>${_escape(section.title)}</h2>')
      ..writeln('      <p>${_paragraph(section.body)}</p>')
      ..writeln('    </section>');
  }
  return '''<!doctype html>
<!-- Fichier généré par tool/generate_privacy_page.dart à partir de lib/legal/privacy.dart. Ne pas modifier à la main. -->
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Confidentialité – Max SecurePass</title>
  <meta name="description" content="${_escape(privacySummary)}">
  <style>
    :root {
      --signal: #0262F4; --deep: #023EB8; --ink: #080E28; --muted: #4A5578;
      --bg: #EEF3FD; --surface: #FFFFFF; --line: #DCE3F3;
    }
    @media (prefers-color-scheme: dark) {
      :root { --signal: #5C97FF; --ink: #E8EEFC; --muted: #9AA8CC; --bg: #080E28;
              --surface: #111A3A; --line: #1E2A55; }
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--ink);
           font: 17px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
    header { background: linear-gradient(90deg, #0262F4 50%, #023EB8 50%); color: #fff;
             padding: 48px 20px 64px; text-align: center;
             clip-path: polygon(0 0, 100% 0, 100% 78%, 50% 100%, 0 78%); }
    header .brand { font-weight: 800; font-size: 28px; letter-spacing: -0.5px; margin: 0; }
    header .brand span { opacity: .72; }
    header h1 { font-size: 18px; font-weight: 600; margin: 8px 0 0; }
    main { max-width: 680px; margin: 0 auto; padding: 24px 16px 48px; }
    .summary { background: var(--surface); border-radius: 18px; padding: 20px 22px;
               font-weight: 600; border-left: 6px solid var(--signal); }
    .date { color: var(--muted); font-size: 14px; margin: 12px 4px 8px; }
    section { background: var(--surface); border-radius: 18px; padding: 4px 22px 8px;
              margin-top: 14px; }
    h2 { font-size: 19px; margin: 18px 0 6px; }
    p { margin: 0 0 14px; }
    a { color: var(--signal); }
    footer { text-align: center; color: var(--muted); font-size: 14px; padding: 0 16px 40px; }
  </style>
</head>
<body>
  <header>
    <p class="brand"><span>Max</span> SecurePass</p>
    <h1>Politique de confidentialité</h1>
  </header>
  <main>
    <p class="summary">${_escape(privacySummary)}</p>
    <p class="date">Dernière mise à jour : ${formatFrenchDate(privacyDate)}</p>
$sections  </main>
  <footer>Contact : <a href="mailto:$contactEmail">$contactEmail</a></footer>
</body>
</html>
''';
}
