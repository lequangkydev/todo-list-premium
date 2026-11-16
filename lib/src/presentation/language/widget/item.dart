part of '../language_screen.dart';

class _LanguageItem extends StatelessWidget {
  const _LanguageItem({
    super.key,
    required this.context,
    required this.language,
    this.selectedValue,
  });

  final BuildContext context;
  final Language language;
  final Language? selectedValue;

  @override
  Widget build(BuildContext context) {
    final selectedLanguageCubit = context.read<ValueCubit<Language?>>();
    final scheme = context.colorScheme;
    final selected = language == selectedValue;
    return Semantics(
      selected: selected,
      button: true,
      label: language.languageName,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : context.taskColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => selectedLanguageCubit.update(language),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.md,
              ),
              child: Row(
                children: [
                  SvgPicture.asset(language.flagPath, width: 28, height: 28),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Text(
                      language.languageName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomRadio<Language?>(
                      value: language,
                      groupValue: selectedValue,
                      onChanged: (value) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
