import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReusablePagination extends StatelessWidget {
  final int totalItems;
  final int itemsPerPage;
  final int currentPage;
  final List<int> allowedRowOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int?> onItemsPerPageChanged;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color inputBg;
  final Color activeColor;
  final String languageCode;

  const ReusablePagination({
    super.key,
    required this.totalItems,
    required this.itemsPerPage,
    required this.currentPage,
    this.allowedRowOptions = const [10, 50, 100],
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.inputBg,
    required this.activeColor,
    this.languageCode = 'id',
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / itemsPerPage).ceil();
    final startIndex = totalItems == 0 ? 0 : (currentPage - 1) * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage) > totalItems
        ? totalItems
        : (startIndex + itemsPerPage);

    final showStart = totalItems == 0 ? 0 : startIndex + 1;
    final isEnglish = languageCode.toLowerCase() == 'en';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: borderColor),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Rows per page dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEnglish ? 'Show' : 'Tampilkan',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: itemsPerPage,
                    dropdownColor: inputBg,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: subtitleColor,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    items: allowedRowOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: onItemsPerPageChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'entries per page' : 'data per halaman',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
            ],
          ),

          // Showing entries info
          Text(
            totalItems == 0
                ? (isEnglish ? 'Showing 0 entries' : 'Menampilkan 0 data')
                : (isEnglish
                    ? 'Showing $showStart to $endIndex of $totalItems entries'
                    : 'Menampilkan $showStart hingga $endIndex dari $totalItems data'),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: subtitleColor,
            ),
          ),

          // Navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavButton(
                icon: Icons.first_page_rounded,
                isEnabled: currentPage > 1,
                onTap: () => onPageChanged(1),
              ),
              const SizedBox(width: 6),
              _buildNavButton(
                icon: Icons.chevron_left_rounded,
                isEnabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentPage / ${totalPages == 0 ? 1 : totalPages}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              _buildNavButton(
                icon: Icons.chevron_right_rounded,
                isEnabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
              ),
              const SizedBox(width: 6),
              _buildNavButton(
                icon: Icons.last_page_rounded,
                isEnabled: currentPage < totalPages,
                onTap: () => onPageChanged(totalPages),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled ? textColor : subtitleColor.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
