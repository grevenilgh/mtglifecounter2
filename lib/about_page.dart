import 'package:flutter/material.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// «Acerca de»: quién hace la app y los avisos legales. El de contenido de
/// fans es la traducción del texto que pide la Política de contenido de fans
/// de Wizards of the Coast; si se cambia, que siga diciendo lo mismo.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String appName = 'MTG Life Counter';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSettingsBackground,
      appBar: AppBar(
        title: const Text('Acerca de'),
        backgroundColor: kSettingsBackground,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _Card(
            children: [
              const Text(
                appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => Text(
                  snapshot.hasData ? 'Versión ${snapshot.data!.version}' : ' ',
                  style: const TextStyle(color: kMutedText, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              const _Paragraph(
                'Hecha por greven.il, sin ánimo de lucro, para la comunidad '
                'de Magic. Gratis y sin anuncios.',
              ),
            ],
          ),
          _Card(
            title: 'Comunidades',
            children: [
              const _Paragraph(
                'Las skins son de estas comunidades. Pásate a verlas:',
              ),
              for (final link in communityLinks) _LinkTile(link),
              const SizedBox(height: 6),
            ],
          ),
          const _Card(
            title: 'Aviso legal',
            children: [
              _Paragraph(
                'MTG Life Counter es contenido de fans no oficial, permitido '
                'por la Política de contenido de fans de Wizards of the '
                'Coast. No está aprobada ni respaldada por Wizards. Parte de '
                'los materiales usados son propiedad de Wizards of the '
                'Coast. © Wizards of the Coast LLC.',
              ),
              _Paragraph(
                'Magic: The Gathering, los nombres e ilustraciones de las '
                'cartas, los símbolos de maná y los marcos de carta son '
                'marcas y propiedad de Wizards of the Coast LLC, filial de '
                'Hasbro, Inc.',
              ),
              _Paragraph(
                'Los logos de AlicanteMTG, Full Tapped y Old School MTG '
                'Channel pertenecen a sus respectivos dueños.',
              ),
            ],
          ),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final info = await PackageInfo.fromPlatform();
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: info.version,
                  applicationLegalese: 'Hecha por greven.il',
                );
              },
              icon: const Icon(Icons.description_outlined),
              label: const Text('Ver licencias de software'),
              style: TextButton.styleFrom(foregroundColor: kAccent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una comunidad con su skin: el nombre, dónde está y su enlace.
typedef CommunityLink = ({
  String name,
  String where,
  IconData icon,
  String url,
});

/// Las webs de las comunidades de cada skin.
const List<CommunityLink> communityLinks = [
  (
    name: 'AlicanteMTG',
    where: 'Liga Premodern Alicante',
    icon: Icons.public,
    url: 'https://sites.google.com/view/liga-premodern-alicante/inicio',
  ),
  (
    name: 'Full Tapped',
    where: 'Canal de YouTube',
    icon: Icons.smart_display_outlined,
    url: 'https://www.youtube.com/@Fulltappedmtg',
  ),
  (
    name: 'Old School MTG Channel',
    where: 'oldschoolmtgchannel.com',
    icon: Icons.public,
    url: 'https://www.oldschoolmtgchannel.com/',
  ),
];

/// Abre la web en el navegador. Si no se puede, lo dice abajo.
class _LinkTile extends StatelessWidget {
  const _LinkTile(this.link);

  final CommunityLink link;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(link.icon, color: kAccent),
      title: Text(link.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(link.where, style: const TextStyle(color: kMutedText)),
      trailing: const Icon(Icons.open_in_new, color: kMutedText, size: 20),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final opened = await launchUrl(
          Uri.parse(link.url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se ha podido abrir la web')),
          );
        }
      },
    );
  }
}

/// Una tarjeta como las de Ajustes, con su título si lo lleva.
class _Card extends StatelessWidget {
  const _Card({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: kMutedText, fontSize: 14, height: 1.45),
      ),
    );
  }
}
