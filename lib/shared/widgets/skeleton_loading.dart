import 'package:flutter/material.dart';

// Centralised pulsing controller for all skeleton elements
class SkeletonScope extends StatefulWidget {
  final Widget child;
  const SkeletonScope({super.key, required this.child});

  static Animation<double>? of(BuildContext context) {
    final _SkeletonScopeState? state = context.findAncestorStateOfType<_SkeletonScopeState>();
    return state?.animation;
  }

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Animation<double> get animation => _animation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
        
    final animation = SkeletonScope.of(context);
    final borderRadiusVal = shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(8));

    final widgetBox = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        shape: shape,
        borderRadius: borderRadiusVal,
      ),
    );

    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(
            opacity: animation.value,
            child: child,
          );
        },
        child: widgetBox,
      );
    }

    return widgetBox;
  }
}

class SkeletonLoading extends StatelessWidget {
  final double? width;
  final double? height;
  final double? borderRadius;

  const SkeletonLoading({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius != null ? BorderRadius.circular(borderRadius!) : null,
    );
  }
}

// 1. SkeletonQueueList - Doctor Queue List
class SkeletonQueueList extends StatelessWidget {
  const SkeletonQueueList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Expanded(flex: 2, child: SkeletonBox(height: 16, width: 30)),
              const SizedBox(width: 8),
              const Expanded(flex: 3, child: SkeletonBox(height: 16, width: 100)),
              const SizedBox(width: 8),
              const Expanded(flex: 2, child: SkeletonBox(height: 16, width: 60)),
              const SizedBox(width: 8),
              const Expanded(flex: 2, child: SkeletonBox(height: 16, width: 50)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: SkeletonBox(height: 24, width: 70, borderRadius: BorderRadius.circular(6))),
            ],
          ),
        );
      },
    );
  }
}

// 2. SkeletonPatientGrid - Doctor Patients Grid
class SkeletonPatientGrid extends StatelessWidget {
  const SkeletonPatientGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 1 : (width < 1200 ? 2 : 3);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        mainAxisExtent: 180,
      ),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(height: 16, width: 120),
                      const SizedBox(height: 8),
                      const SkeletonBox(height: 12, width: 80),
                      const SizedBox(height: 12),
                      const SkeletonBox(height: 12, width: 140),
                      const SizedBox(height: 8),
                      const SkeletonBox(height: 12, width: 100),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SkeletonBox(height: 28, width: 70, borderRadius: BorderRadius.circular(6)),
                          const SizedBox(width: 8),
                          SkeletonBox(height: 28, width: 70, borderRadius: BorderRadius.circular(6)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// 3. SkeletonAssistantGrid - Doctor Assistants Grid
class SkeletonAssistantGrid extends StatelessWidget {
  const SkeletonAssistantGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 1 : (width < 1200 ? 2 : 3);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 200,
      ),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(height: 14, width: 100),
                          SizedBox(height: 6),
                          SkeletonBox(height: 10, width: 60),
                        ],
                      ),
                    ),
                    SkeletonBox(height: 20, width: 50, borderRadius: BorderRadius.circular(12)),
                  ],
                ),
                const SizedBox(height: 16),
                const SkeletonBox(height: 12, width: 150),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12, width: 120),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SkeletonBox(height: 28, width: 60, borderRadius: BorderRadius.circular(8)),
                    const SizedBox(width: 8),
                    SkeletonBox(height: 28, width: 60, borderRadius: BorderRadius.circular(8)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 4. SkeletonHistoryList - Patient History & Prescription List
class SkeletonHistoryList extends StatelessWidget {
  final bool isPrescription;
  const SkeletonHistoryList({super.key, this.isPrescription = false});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(height: 12, width: 80),
                    SkeletonBox(height: 20, width: 70, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
                const SizedBox(height: 12),
                const SkeletonBox(height: 16, width: 180),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12, width: 220),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(height: 12, width: 100),
                    if (isPrescription)
                      SkeletonBox(height: 32, width: 110, borderRadius: BorderRadius.circular(8))
                    else
                      SkeletonBox(height: 24, width: 80, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 5. SkeletonProfile - Doctor / Patient Profile loading
class SkeletonProfile extends StatelessWidget {
  final bool isDoctor;
  const SkeletonProfile({super.key, this.isDoctor = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Banner Skeleton
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const SkeletonBox(width: 80, height: 80, shape: BoxShape.circle),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 20, width: 150),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12, width: 100),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12, width: 180),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Multiple details sections
          ...List.generate(3, (index) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(height: 16, width: 120),
                    const SizedBox(height: 16),
                    ...List.generate(3, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SkeletonBox(height: 12, width: 90),
                            SkeletonBox(height: 12, width: idx % 2 == 0 ? 150 : 80),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// 6. SkeletonDashboard - Patient Dashboard
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top User card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const SkeletonBox(width: 70, height: 70, shape: BoxShape.circle),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 18, width: 120),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12, width: 80),
                        SizedBox(height: 8),
                        SkeletonBox(height: 10, width: 150),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick actions grid
          const SkeletonBox(height: 16, width: 100),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              return Column(
                children: const [
                  SkeletonBox(width: 56, height: 56, shape: BoxShape.circle),
                  SizedBox(height: 8),
                  SkeletonBox(width: 50, height: 10),
                ],
              );
            }),
          ),
          const SizedBox(height: 28),
          // Active items section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 16, width: 140),
                  SizedBox(height: 16),
                  SkeletonBox(height: 12, width: double.infinity),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 7. SkeletonApotekDashboard - Pharmacy Dashboard screens
class SkeletonApotekDashboard extends StatelessWidget {
  final String type;
  const SkeletonApotekDashboard({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metric cards row
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 10, width: 80),
                        SizedBox(height: 8),
                        SkeletonBox(height: 20, width: 120),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 10, width: 80),
                        SizedBox(height: 8),
                        SkeletonBox(height: 20, width: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search & Filter controls
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 40, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 12),
              SkeletonBox(height: 40, width: 100, borderRadius: BorderRadius.circular(10)),
            ],
          ),
          const SizedBox(height: 20),
          // Content representation (Table rows or Cards)
          if (type == 'inventory' || type == 'sales' || type == 'orders')
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(height: 14, width: 140),
                            SizedBox(height: 6),
                            SkeletonBox(height: 10, width: 80),
                          ],
                        ),
                      ),
                      const SkeletonBox(height: 14, width: 60),
                    ],
                  ),
                );
              },
            )
          else // Report / Charts / Info
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(height: 16, width: 120),
                    const SizedBox(height: 20),
                    // Fake chart visualizer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final heights = [100.0, 160.0, 80.0, 140.0, 200.0, 110.0, 170.0];
                        return Column(
                          children: [
                            SkeletonBox(
                              width: 24,
                              height: heights[index],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            const SkeletonBox(width: 16, height: 8),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 8. SkeletonPembukuan - Doctor Bookkeeping / Pembukuan Screen loading
class SkeletonPembukuan extends StatelessWidget {
  const SkeletonPembukuan({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                const SkeletonBox(width: 38, height: 38, borderRadius: BorderRadius.all(Radius.circular(12))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(height: 20, width: 140),
                      SizedBox(height: 6),
                      SkeletonBox(height: 12, width: 220),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SkeletonBox(height: 36, width: 110, borderRadius: BorderRadius.all(Radius.circular(10))),
                  const SizedBox(width: 12),
                  const SkeletonBox(height: 36, width: 140, borderRadius: BorderRadius.all(Radius.circular(10))),
                ],
              ],
            ),
          ),

          // Metric Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: List.generate(
              4,
              (i) => Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          SkeletonBox(width: 22, height: 22, borderRadius: BorderRadius.all(Radius.circular(6))),
                          SizedBox(width: 8),
                          SkeletonBox(height: 12, width: 70),
                        ],
                      ),
                      const SkeletonBox(height: 22, width: 100),
                      const SkeletonBox(height: 12, width: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tab toggles
          Row(
            children: const [
              SkeletonBox(height: 36, width: 160, borderRadius: BorderRadius.all(Radius.circular(100))),
              SizedBox(width: 12),
              SkeletonBox(height: 36, width: 180, borderRadius: BorderRadius.all(Radius.circular(100))),
            ],
          ),

          const SizedBox(height: 20),

          // Charts area
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 14, width: 160),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12, width: 220),
                        SizedBox(height: 20),
                        SkeletonBox(height: 160, width: double.infinity),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (!isMobile)
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SkeletonBox(height: 14, width: 100),
                          ),
                          const SizedBox(height: 20),
                          const SkeletonBox(width: 130, height: 130, shape: BoxShape.circle),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 12, width: double.infinity),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 12, width: double.infinity),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Table card
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table controls row
                  Row(
                    children: const [
                      SkeletonBox(height: 12, width: 60),
                      SizedBox(width: 16),
                      SkeletonBox(height: 12, width: 120),
                      Spacer(),
                      SkeletonBox(height: 28, width: 80),
                      SizedBox(width: 8),
                      SkeletonBox(height: 28, width: 100),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Table columns header row
                  const SkeletonBox(height: 36, width: double.infinity),
                  const SizedBox(height: 12),
                  // Rows
                  ...List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: const [
                          SkeletonBox(height: 14, width: 80),
                          SizedBox(width: 16),
                          Expanded(child: SkeletonBox(height: 14, width: double.infinity)),
                          SizedBox(width: 16),
                          SkeletonBox(height: 14, width: 60),
                          SizedBox(width: 16),
                          SkeletonBox(height: 14, width: 70),
                          SizedBox(width: 16),
                          SkeletonBox(height: 14, width: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

