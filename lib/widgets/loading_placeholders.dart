import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/shimmer_loading.dart';

class ListTileShimmer extends StatelessWidget {
  const ListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.white),
        title: Container(
          width: double.infinity,
          height: 16.0,
          color: Colors.white,
        ),
        subtitle: Container(
          width: double.infinity,
          height: 14.0,
          margin: const EdgeInsets.only(right: 40),
          color: Colors.white,
        ),
      ),
    );
  }
}

class ArtistsListShimmer extends StatelessWidget {
  const ArtistsListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: context.w(140),
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(20), vertical: context.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShimmerLoading(
                      child: Container(
                        width: 200,
                        height: 32,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    SizedBox(height: context.w(8)),
                    ShimmerLoading(
                      child: Container(
                        width: 150,
                        height: 20,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.w(16), 0, context.w(16), context.w(16)),
            child: ShimmerLoading(
              child: Container(
                height: 56,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(context.w(20))),
              ),
            ),
          ),
        ),
        _buildShimmerSectionHeader(context),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: context.w(12),
              crossAxisSpacing: context.w(12),
              childAspectRatio: 2.6,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => ShimmerLoading(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(context.w(16))),
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
        _buildShimmerSectionHeader(context),
        SliverToBoxAdapter(
          child: SizedBox(
            height: context.w(195),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.w(16)),
              itemCount: 3,
              itemBuilder: (context, index) {
                return ShimmerLoading(
                  child: Container(
                    width: context.w(120),
                    margin: EdgeInsets.only(right: context.w(16)),
                    child: Column(
                      children: [
                        CircleAvatar(radius: context.w(55), backgroundColor: Colors.white),
                        SizedBox(height: context.w(12)),
                        Container(height: 16, width: 100, color: Colors.white),
                        SizedBox(height: context.w(8)),
                        Container(height: 14, width: 70, color: Colors.white),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.w(80))),
      ],
    );
  }

  Widget _buildShimmerSectionHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(left: context.w(16), right: context.w(16), top: context.w(24), bottom: context.w(16)),
        child: ShimmerLoading(
          child: Row(
            children: [
              Container(width: context.w(40), height: context.w(40), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(context.w(12)))),
              SizedBox(width: context.w(12)),
              Container(width: 150, height: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonCardShimmer extends StatelessWidget {
  const LessonCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.white,
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    height: 24,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 22,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 6),
                  ),
                  Container(
                    height: 16,
                    width: 200,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 150,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}