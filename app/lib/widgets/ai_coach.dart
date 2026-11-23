import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/coach_message.dart';
import '../services/ai_coach_chat.dart';
import '../services/ai_coach_service.dart';
import 'common_widgets.dart';

/// Bouton flottant « AI Coach » (en bas à droite des écrans principaux).
class AiCoachButton extends StatelessWidget {
  /// Version large avec le libellé (grand écran) ; sinon bouton rond avec infobulle.
  final bool extended;
  const AiCoachButton({super.key, this.extended = false});

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.smart_toy_rounded);
    void open() => openAiCoach(context);
    return extended
        ? FloatingActionButton.extended(
            heroTag: 'ai-coach',
            tooltip: 'AI Coach',
            onPressed: open,
            icon: icon,
            label: const Text('AI Coach'),
          )
        : FloatingActionButton(
            heroTag: 'ai-coach',
            tooltip: 'AI Coach',
            onPressed: open,
            child: icon,
          );
  }
}

/// Members use a side panel; other roles retain their existing chat layout.
Future<void> openAiCoach(BuildContext context, {bool sidePanel = false}) {
  final size = MediaQuery.sizeOf(context);
  if (sidePanel || size.width >= 700) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer AI Coach',
      barrierColor: Colors.black38,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.viewInsetsOf(dialogContext).bottom,
            ),
            child: SizedBox(
              width: size.width < 444 ? size.width - 24 : 420,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.surface,
                child: const AiCoachPanel(wide: true),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (c) {
      final inset = MediaQuery.viewInsetsOf(c).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: (MediaQuery.sizeOf(c).height - inset) * 0.92,
          child: const AiCoachPanel(),
        ),
      );
    },
  );
}

/// Panneau de conversation AI Coach.
class AiCoachPanel extends StatefulWidget {
  final bool wide;
  const AiCoachPanel({super.key, this.wide = false});
  @override
  State<AiCoachPanel> createState() => _AiCoachPanelState();
}

class _AiCoachPanelState extends State<AiCoachPanel> {
  final chat = AiCoachChat.instance;
  final input = TextEditingController();
  final scroll = ScrollController();
  final inputFocus = FocusNode();
  /// null : inconnu (le serveur dira l'erreur à l'envoi si besoin).
  bool? enabled;

  @override
  void initState() {
    super.initState();
    chat.addListener(_changed);
    input.addListener(() => setState(() {}));
    AiCoachService.enabled().then((v) {
      if (mounted) setState(() => enabled = v);
    }, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(jump: true));
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    input.dispose();
    scroll.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _toBottom({bool jump = false}) {
    if (!scroll.hasClients) return;
    final end = scroll.position.maxScrollExtent;
    jump ? scroll.jumpTo(end) : scroll.animateTo(end, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  void _submit([String? text]) {
    final t = (text ?? input.text).trim();
    if (t.isEmpty || chat.busy || enabled == false) return;
    input.clear();
    chat.send(t);
    inputFocus.requestFocus();
  }

  void _close() => Navigator.of(context).maybePop();

  List<String> get _suggestions {
    if (Api.isAdmin) {
      return const ['Comment réduire les abandons de membres ?', 'Idées de cours collectifs à proposer', 'Comment fidéliser après l\'abonnement ?'];
    }
    if (Api.inCoachSpace) {
      return const ['Programme de 4 semaines pour un débutant', 'Comment motiver un client qui décroche ?', 'Comment commenter une séance utilement ?'];
    }
    return const ['Analyse mes dernières séances', 'Que faire à ma prochaine séance ?', 'Comment progresser plus vite ?', 'Conseils de récupération'];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final messages = chat.messages;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(children: [
        const IconBadge(Icons.smart_toy_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('AI Coach', style: text.titleMedium)),
            Text('Votre coach virtuel IronFit', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        IconButton(
          tooltip: 'Effacer la conversation',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: chat.isEmpty && chat.status == CoachStatus.idle ? null : chat.clear,
        ),
        IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close_rounded), onPressed: _close),
      ]),
    );

    final Widget body;
    if (messages.isEmpty && chat.status == CoachStatus.idle) {
      body = ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 16), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(gradient: AppColors.amberGradient, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded, size: 36, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 14),
        Text('Bonjour${Api.user == null ? '' : ' ${Api.user!.firstName}'} !', textAlign: TextAlign.center, style: text.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Posez une question sur votre entraînement, votre progression ou la récupération. '
          'Le coach s\'appuie sur vos données IronFit.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final s in _suggestions)
            ActionChip(label: Text(s), avatar: const Icon(Icons.bolt_rounded, size: 18), onPressed: enabled == false ? null : () => _submit(s)),
        ]),
      ]);
    } else {
      body = ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        children: [
          for (final m in messages) _Bubble(m),
          if (chat.status == CoachStatus.waiting) const _TypingBubble(),
        ],
      );
    }

    final canSend = input.text.trim().isNotEmpty && !chat.busy && enabled != false;
    final composer = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          // Entrée : envoyer ; Maj + Entrée : nouvelle ligne
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, e) {
              final enter = e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter;
              if (e is KeyDownEvent && enter && !HardwareKeyboard.instance.isShiftPressed) {
                _submit();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: input,
              focusNode: inputFocus,
              autofocus: widget.wide,
              enabled: enabled != false,
              minLines: 1,
              maxLines: 5,
              maxLength: AppConfig.aiCoachMaxChars,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  currentLength > AppConfig.aiCoachMaxChars - 200 ? Text('$currentLength / $maxLength') : null,
              decoration: InputDecoration(
                hintText: enabled == false ? 'AI Coach est indisponible' : 'Écrivez votre message…',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: chat.busy
              ? IconButton.filledTonal(tooltip: 'Arrêter la réponse', icon: const Icon(Icons.stop_rounded), onPressed: chat.stop)
              : IconButton.filled(
                  tooltip: 'Envoyer',
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
                  onPressed: canSend ? _submit : null,
                ),
        ),
      ]),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: !widget.wide,
        child: Column(children: [
          header,
          const Divider(),
          if (enabled == false)
            _Banner(
              icon: Icons.info_outline_rounded,
              color: cs.onSurfaceVariant,
              background: cs.surfaceContainerHigh,
              text: 'AI Coach n\'est pas encore configuré sur le serveur. L\'administrateur doit renseigner OPENROUTER_API_KEY.',
            ),
          Expanded(child: body),
          if (chat.status == CoachStatus.failed && chat.error != null)
            _Banner(
              icon: Icons.error_outline_rounded,
              color: cs.onErrorContainer,
              background: cs.errorContainer,
              text: chat.error!,
              action: chat.isEmpty ? null : TextButton(onPressed: chat.retry, child: const Text('Réessayer')),
            ),
          composer,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Conseils généraux, pas un avis médical. Vos données servent uniquement à personnaliser les réponses.',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Bulle de message : utilisateur à droite (ambre), coach à gauche (texte sélectionnable).
class _Bubble extends StatelessWidget {
  final CoachMessage m;
  const _Bubble(this.m);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = m.isUser;
    const r = Radius.circular(18);
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Semantics(
          label: user ? 'Vous' : 'AI Coach',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: user ? AppColors.amber : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.only(topLeft: r, topRight: r, bottomLeft: user ? r : const Radius.circular(4), bottomRight: user ? const Radius.circular(4) : r),
            ),
            child: user
                ? Text(m.content, style: const TextStyle(color: AppColors.ink, height: 1.35))
                : SelectableText.rich(TextSpan(children: coachSpans(m.content)), style: TextStyle(color: cs.onSurface, height: 1.4)),
          ),
        ),
      ),
    );
  }
}

/// Mise en forme légère des réponses : **gras** et titres « # » (les petits modèles en écrivent malgré la consigne) ;
/// le reste (listes « - », « 1. ») reste du texte brut. Un « ** » non refermé (réponse en cours) reste affiché tel quel.
List<InlineSpan> coachSpans(String text) {
  const bold = TextStyle(fontWeight: FontWeight.w700);
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(line);
    if (heading != null) {
      spans.add(TextSpan(text: line.substring(heading.end).replaceAll('**', ''), style: bold));
    } else {
      var start = 0;
      for (final m in RegExp(r'\*\*(.+?)\*\*').allMatches(line)) {
        if (m.start > start) spans.add(TextSpan(text: line.substring(start, m.start)));
        spans.add(TextSpan(text: m.group(1), style: bold));
        start = m.end;
      }
      if (start < line.length) spans.add(TextSpan(text: line.substring(start)));
    }
    if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

/// Indicateur « AI Coach écrit… » en attendant le premier morceau de réponse.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: 'AI Coach écrit…',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35 + 0.65 * (((anim.value * 3 - i) % 3) < 1 ? 1 : 0)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  final String text;
  final Widget? action;
  const _Banner({required this.icon, required this.color, required this.background, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color))),
            ?action,
          ]),
        ),
      );
}
