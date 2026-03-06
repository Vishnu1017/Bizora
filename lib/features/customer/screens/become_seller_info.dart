import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bizora/features/customer/screens/become_owner_screen.dart';

class BecomeSellerInfoScreen extends StatefulWidget {
  const BecomeSellerInfoScreen({super.key});

  @override
  State<BecomeSellerInfoScreen> createState() => _BecomeSellerInfoScreenState();
}

class _BecomeSellerInfoScreenState extends State<BecomeSellerInfoScreen> {
  // Track expanded FAQ items
  final Set<int> _expandedFaqs = {};

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [_buildHeader(isMobile), _buildMainContent(isMobile)],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B2F8C), // Deep Purple
            Color(0xFF9C27B0), // Purple
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 32),
          child: Column(
            children: [
              Row(
                children: [
                  _buildBackButton(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Become a Seller',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildHeroSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join 15,000+ Successful Sellers',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your online business journey with Bizora Marketplace and reach millions of customers across India',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront,
              color: Color(0xFF6B2F8C),
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(),
          const SizedBox(height: 32),
          _buildBenefitsSection(isMobile),
          const SizedBox(height: 32),
          _buildFeaturesSection(),
          const SizedBox(height: 32),
          _buildHowItWorksSection(),
          const SizedBox(height: 32),
          _buildCommissionSection(),
          const SizedBox(height: 32),
          _buildRequirementsSection(),
          const SizedBox(height: 32),
          _buildFAQSection(),
          const SizedBox(height: 32),
          _buildTestimonialsSection(),
          const SizedBox(height: 32),
          _buildCTASection(),
          const SizedBox(height: 20),
          _buildTrustIndicators(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('15K+', 'Active Sellers', Icons.people),
              _buildStatItem('₹50Cr+', 'Monthly GMV', Icons.trending_up),
              _buildStatItem('2M+', 'Customers', Icons.shopping_cart),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('24K+', 'Products', Icons.inventory),
              _buildStatItem('50+', 'Categories', Icons.category),
              _buildStatItem('99%', 'Happy Sellers', Icons.star),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Why Sell with Bizora?', Icons.star),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 1 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: const [
            _BenefitCard(
              icon: Icons.people,
              title: '10 Lakh+ Customers',
              subtitle: 'Massive customer base across India',
              color: Colors.blue,
            ),
            _BenefitCard(
              icon: Icons.currency_rupee,
              title: '0% Commission',
              subtitle: 'Zero commission for first 3 months',
              color: Colors.green,
            ),
            _BenefitCard(
              icon: Icons.payments,
              title: '7-Day Settlements',
              subtitle: 'Fast and reliable payment cycle',
              color: Colors.orange,
            ),
            _BenefitCard(
              icon: Icons.support_agent,
              title: 'Dedicated Support',
              subtitle: '24/7 seller support team',
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Everything You Get', Icons.inventory),
        const SizedBox(height: 16),
        const _FeatureItem(
          icon: Icons.dashboard,
          title: 'Seller Dashboard',
          description:
              'Comprehensive dashboard with real-time sales, orders, and analytics. Track your business performance at a glance.',
        ),
        const _FeatureItem(
          icon: Icons.inventory,
          title: 'Advanced Product Management',
          description:
              'Bulk product upload, inventory management, variant support, and image optimization tools.',
        ),
        const _FeatureItem(
          icon: Icons.shopping_bag,
          title: 'Smart Order Management',
          description:
              'Automated order processing, invoice generation, return management, and shipping labels.',
        ),
        const _FeatureItem(
          icon: Icons.analytics,
          title: 'Real-time Analytics',
          description:
              'Detailed insights on sales, customer behavior, top products, and revenue trends.',
        ),
        const _FeatureItem(
          icon: Icons.payment,
          title: 'Multiple Payment Options',
          description:
              'Accept payments via UPI, Cards, NetBanking, Wallet, and COD. Daily settlements to your bank.',
        ),
        const _FeatureItem(
          icon: Icons.local_shipping,
          title: 'Integrated Shipping',
          description:
              'Pan-India shipping with Delhivery, BlueDart, and other partners. Automated label generation.',
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('How It Works', Icons.timeline),
        const SizedBox(height: 16),
        const _StepItem(
          number: 1,
          title: 'Submit Application',
          description:
              'Fill out the seller application with your business details, GST, and PAN information.',
          color: Color(0xFF2196F3),
        ),
        const _StepItem(
          number: 2,
          title: 'Document Verification',
          description:
              'Upload required documents for verification. Our team verifies within 24-48 hours.',
          color: Color(0xFFFF9800),
        ),
        const _StepItem(
          number: 3,
          title: 'Admin Review',
          description:
              'Our team reviews your application, business details, and category preferences.',
          color: Color(0xFF9C27B0),
        ),
        const _StepItem(
          number: 4,
          title: 'Start Selling',
          description:
              'Get approved and access your seller dashboard. Start listing products immediately.',
          color: Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildCommissionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.percent, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              const Text(
                'Commission Structure',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _CommissionRow(category: 'Electronics', commission: '8-12%'),
          const _CommissionRow(category: 'Fashion', commission: '10-15%'),
          const _CommissionRow(category: 'Grocery', commission: '5-8%'),
          const _CommissionRow(category: 'Home & Living', commission: '7-10%'),
          const _CommissionRow(category: 'Books', commission: '5-7%'),
          const Divider(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.green.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'First 3 months: 0% commission for all categories',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Requirements', Icons.assignment_turned_in),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: const [
              _RequirementItem(
                text:
                    'Valid GST Certificate (Mandatory for businesses above ₹40L)',
                icon: Icons.receipt,
              ),
              Divider(),
              _RequirementItem(
                text: 'PAN Card (Mandatory for all sellers)',
                icon: Icons.credit_card,
              ),
              Divider(),
              _RequirementItem(
                text:
                    'Business Address Proof (Electricity bill / Rent agreement)',
                icon: Icons.location_on,
              ),
              Divider(),
              _RequirementItem(
                text: 'Bank Account Details (For settlements)',
                icon: Icons.account_balance,
              ),
              Divider(),
              _RequirementItem(
                text: 'Shop Photos (2-5 high-quality images)',
                icon: Icons.photo_camera,
              ),
              Divider(),
              _RequirementItem(
                text: 'Cancelled Cheque or Bank Statement',
                icon: Icons.check_circle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Frequently Asked Questions', Icons.help),
        const SizedBox(height: 16),
        _FAQItem(
          question: 'How long does the approval process take?',
          answer:
              'Most applications are reviewed within 24-48 hours. In some cases, it might take up to 72 hours if additional verification is needed.',
          isExpanded: _expandedFaqs.contains(0),
          onTap: () => _toggleFaq(0),
        ),
        _FAQItem(
          question: 'What are the commission charges after 3 months?',
          answer:
              'Commission ranges from 5-15% depending on the product category. Electronics: 8-12%, Fashion: 10-15%, Grocery: 5-8%, Home & Living: 7-10%.',
          isExpanded: _expandedFaqs.contains(1),
          onTap: () => _toggleFaq(1),
        ),
        _FAQItem(
          question: 'When and how do I get paid?',
          answer:
              'Payments are settled every 7 days directly to your registered bank account. Minimum payout amount is ₹1000. You can track all settlements in your dashboard.',
          isExpanded: _expandedFaqs.contains(2),
          onTap: () => _toggleFaq(2),
        ),
        _FAQItem(
          question: 'Can I sell in multiple categories?',
          answer:
              'Yes, you can sell in multiple categories after approval. Each category may have different commission rates. You can add categories later through your dashboard.',
          isExpanded: _expandedFaqs.contains(3),
          onTap: () => _toggleFaq(3),
        ),
        _FAQItem(
          question: 'What is the shipping process?',
          answer:
              'We provide integrated shipping with major courier partners. You pack the products, generate shipping labels from your dashboard, and our partners pick up from your location.',
          isExpanded: _expandedFaqs.contains(4),
          onTap: () => _toggleFaq(4),
        ),
        _FAQItem(
          question: 'Is there any registration or monthly fee?',
          answer:
              'No registration fee, no monthly fee. You only pay commission on successful sales. First 3 months have 0% commission as a welcome offer.',
          isExpanded: _expandedFaqs.contains(5),
          onTap: () => _toggleFaq(5),
        ),
      ],
    );
  }

  void _toggleFaq(int index) {
    setState(() {
      if (_expandedFaqs.contains(index)) {
        _expandedFaqs.remove(index);
      } else {
        _expandedFaqs.add(index);
      }
    });
  }

  Widget _buildTestimonialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('What Our Sellers Say', Icons.rate_review),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _TestimonialCard(
                name: 'Rajesh Kumar',
                shop: 'ElectroWorld',
                review:
                    'Bizora helped me grow my electronics business 10x in just 6 months. The support team is amazing!',
                rating: 5,
              ),
              _TestimonialCard(
                name: 'Priya Sharma',
                shop: 'FashionHub',
                review:
                    'Started from home, now shipping 500+ orders monthly. Best platform for new sellers.',
                rating: 5,
              ),
              _TestimonialCard(
                name: 'Amit Patel',
                shop: 'HomeDecor',
                review:
                    'The analytics dashboard is a game-changer. I know exactly what my customers want.',
                rating: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCTASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B2F8C), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Start Your Journey?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join 15,000+ successful sellers on Bizora',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Swipe to Become a Owner Button
          const _SwipeButton(),
        ],
      ),
    );
  }

  Widget _buildTrustIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustIndicator(Icons.security, '100% Secure'),
        Container(width: 1, height: 20, color: Colors.grey.shade300),
        _buildTrustIndicator(Icons.verified_user, 'Verified Sellers'),
        Container(width: 1, height: 20, color: Colors.grey.shade300),
        _buildTrustIndicator(Icons.support_agent, '24/7 Support'),
      ],
    );
  }

  Widget _buildTrustIndicator(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.deepPurple, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SwipeButton extends StatefulWidget {
  const _SwipeButton();

  @override
  State<_SwipeButton> createState() => __SwipeButtonState();
}

class __SwipeButtonState extends State<_SwipeButton>
    with TickerProviderStateMixin {
  double dragPosition = 0.0;
  bool isDragging = false;

  final double buttonWidth = 60;
  final double verticalPadding = 5;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final maxDrag = containerWidth - buttonWidth - (verticalPadding * 2);

        return Container(
          width: double.infinity,
          height: 65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),

            /// Modern gradient
            gradient: const LinearGradient(
              colors: [Color(0xFF6B2F8C), Color(0xFF9C27B0)],
            ),

            /// Modern glowing border
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),

            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.50),
                blurRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                /// Purple swipe progress
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: dragPosition + buttonWidth,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB967E3), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),

                /// Shiny glass sweep
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (_, __) {
                    return Positioned(
                      left:
                          -containerWidth +
                          (_shimmerController.value * containerWidth * 2),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: containerWidth * 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.25),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                /// Text
                /// swipe text
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, textConstraints) {
                      final progress = (dragPosition / maxDrag).clamp(
                        0.0,
                        1.0,
                      ); // swipe progress 0 → 1

                      final opacity = 1 - (progress * 0.5); // fade slightly
                      final slide = -progress * 40; // move text slightly left

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: Transform.translate(
                            offset: Offset(slide, 0),
                            child: Opacity(
                              opacity: opacity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: isDragging
                                            ? 1
                                            : _pulseAnimation.value,
                                        child: const Icon(
                                          Icons.swipe_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Swipe to Become a Seller",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                /// Slider
                Positioned(
                  left: dragPosition,
                  top: verticalPadding,
                  bottom: verticalPadding,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      setState(() {
                        isDragging = true;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        dragPosition += details.delta.dx;
                        dragPosition = dragPosition.clamp(0.0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() {
                        isDragging = false;
                      });

                      if (dragPosition >= maxDrag * 0.85) {
                        /// Snap to end
                        setState(() {
                          dragPosition = maxDrag;
                        });

                        Future.delayed(const Duration(milliseconds: 200), () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const BecomeOwnerScreen(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    var fade =
                                        Tween<double>(
                                          begin: 0.0,
                                          end: 1.0,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOut,
                                          ),
                                        );

                                    var scale =
                                        Tween<double>(
                                          begin: 0.8,
                                          end: 1.0,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.elasticOut,
                                          ),
                                        );

                                    return FadeTransition(
                                      opacity: fade,
                                      child: ScaleTransition(
                                        scale: scale,
                                        child: child,
                                      ),
                                    );
                                  },
                            ),
                          );
                        });
                      } else {
                        setState(() {
                          dragPosition = 0;
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: buttonWidth,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: isDragging ? 25 : 15,
                            spreadRadius: isDragging ? 4 : 2,
                          ),
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF6B2F8C),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final Color color;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  final String category;
  final String commission;

  const _CommissionRow({required this.category, required this.commission});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              commission,
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String text;
  final IconData icon;

  const _RequirementItem({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
          Icon(Icons.check_circle, size: 18, color: Colors.green.shade400),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FAQItem({
    required this.question,
    required this.answer,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  answer,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String name;
  final String shop;
  final String review;
  final int rating;

  const _TestimonialCard({
    required this.name,
    required this.shop,
    required this.review,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 18,
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '"$review"',
            style: const TextStyle(fontSize: 13, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          const Divider(),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      shop,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
