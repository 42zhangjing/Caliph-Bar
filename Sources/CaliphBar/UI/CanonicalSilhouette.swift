import SwiftUI
import CoreGraphics

enum CanonicalSilhouette {
    static let width: CGFloat = 600.0
    static let height: CGFloat = 1864.0
    static let aspectRatio: CGFloat = 600.0 / 1864.0

    static func appendPath(to path: inout Path, in rect: CGRect, side: EdgeSide) {
        let scale = rect.height / height
        let visibleMaxX = rect.maxX - SideNotchLayout.edgeBleed
        let visibleMinX = visibleMaxX - width * scale

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: visibleMinX + x * scale, y: rect.minY + y * scale)
        }

        // Outer contour - silky smooth, zero-aliasing, G2-continuous with seamless display bleed
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: pt(600.0, 0.0))
        path.addLine(to: pt(598.0, 4.0))
        path.addCurve(to: pt(588.0, 25.7), control1: pt(596.3, 7.6), control2: pt(601.2, 11.7))
        path.addCurve(to: pt(519.0, 88.0), control1: pt(574.8, 39.7), control2: pt(533.7, 70.3))
        path.addCurve(to: pt(500.0, 132.0), control1: pt(504.3, 105.7), control2: pt(503.2, 124.7))
        path.addCurve(to: pt(476.5, 134.0), control1: pt(496.1, 132.3), control2: pt(486.2, 127.3))
        path.addCurve(to: pt(441.5, 172.0), control1: pt(466.8, 140.7), control2: pt(447.3, 165.7))
        path.addCurve(to: pt(438.0, 171.0), control1: pt(440.9, 171.8), control2: pt(438.6, 171.2))
        path.addCurve(to: pt(444.0, 153.0), control1: pt(439.0, 168.0), control2: pt(444.7, 158.9))
        path.addCurve(to: pt(433.7, 135.8), control1: pt(443.3, 147.1), control2: pt(438.7, 141.7))
        path.addCurve(to: pt(414.4, 117.8), control1: pt(428.8, 129.9), control2: pt(422.2, 123.7))
        path.addCurve(to: pt(387.0, 99.9), control1: pt(406.6, 111.8), control2: pt(396.1, 105.2))
        path.addCurve(to: pt(359.6, 85.6), control1: pt(377.9, 94.5), control2: pt(368.0, 88.9))
        path.addCurve(to: pt(336.7, 79.6), control1: pt(351.2, 82.2), control2: pt(343.6, 79.8))
        path.addCurve(to: pt(318.0, 84.1), control1: pt(329.8, 79.3), control2: pt(323.4, 81.3))
        path.addCurve(to: pt(304.4, 96.4), control1: pt(312.6, 86.9), control2: pt(308.1, 91.7))
        path.addCurve(to: pt(296.0, 112.0), control1: pt(300.8, 101.0), control2: pt(296.5, 105.8))
        path.addCurve(to: pt(301.6, 133.6), control1: pt(295.5, 118.2), control2: pt(300.7, 130.0))
        path.addCurve(to: pt(293.0, 124.0), control1: pt(300.2, 132.0), control2: pt(294.9, 128.6))
        path.addCurve(to: pt(290.0, 106.0), control1: pt(291.1, 119.4), control2: pt(290.5, 109.0))
        path.addCurve(to: pt(286.0, 120.0), control1: pt(289.3, 108.3), control2: pt(285.7, 115.2))
        path.addCurve(to: pt(292.0, 135.0), control1: pt(286.3, 124.8), control2: pt(291.0, 132.5))
        path.addCurve(to: pt(284.5, 150.5), control1: pt(290.8, 137.6), control2: pt(288.2, 146.6))
        path.addCurve(to: pt(269.5, 158.6), control1: pt(280.8, 154.4), control2: pt(272.0, 157.2))
        path.addCurve(to: pt(262.6, 150.0), control1: pt(268.4, 157.2), control2: pt(263.8, 151.4))
        path.addCurve(to: pt(266.0, 162.0), control1: pt(263.2, 152.0), control2: pt(265.4, 160.0))
        path.addCurve(to: pt(262.0, 165.0), control1: pt(265.3, 162.5), control2: pt(268.1, 164.4))
        path.addCurve(to: pt(229.4, 165.4), control1: pt(255.9, 165.6), control2: pt(234.8, 165.3))
        path.addCurve(to: pt(228.6, 184.6), control1: pt(229.3, 168.6), control2: pt(228.7, 181.4))
        path.addCurve(to: pt(222.0, 188.0), control1: pt(227.5, 185.2), control2: pt(226.4, 180.8))
        path.addCurve(to: pt(202.0, 228.0), control1: pt(217.6, 195.2), control2: pt(205.3, 221.3))
        path.addCurve(to: pt(204.5, 235.5), control1: pt(202.4, 229.2), control2: pt(200.3, 231.7))
        path.addCurve(to: pt(226.9, 251.1), control1: pt(208.7, 239.3), control2: pt(220.2, 246.0))
        path.addCurve(to: pt(245.0, 266.0), control1: pt(233.7, 256.1), control2: pt(241.2, 251.1))
        path.addCurve(to: pt(250.0, 340.6), control1: pt(248.8, 280.9), control2: pt(249.2, 328.2))
        path.addCurve(to: pt(228.0, 365.0), control1: pt(246.3, 344.7), control2: pt(235.0, 357.0))
        path.addCurve(to: pt(207.7, 388.7), control1: pt(221.0, 373.0), control2: pt(216.2, 380.6))
        path.addCurve(to: pt(177.2, 413.4), control1: pt(199.3, 396.8), control2: pt(188.0, 404.9))
        path.addCurve(to: pt(143.0, 440.0), control1: pt(166.4, 422.0), control2: pt(152.1, 430.8))
        path.addCurve(to: pt(122.7, 468.6), control1: pt(133.9, 449.2), control2: pt(125.8, 458.9))
        path.addCurve(to: pt(124.7, 498.5), control1: pt(119.7, 478.4), control2: pt(121.6, 488.6))
        path.addCurve(to: pt(141.6, 528.0), control1: pt(127.9, 508.4), control2: pt(132.7, 502.9))
        path.addCurve(to: pt(178.0, 649.0), control1: pt(150.5, 553.1), control2: pt(171.9, 628.8))
        path.addCurve(to: pt(0.0, 837.0), control1: pt(148.3, 680.3), control2: pt(29.7, 805.7))
        path.addCurve(to: pt(12.0, 835.0), control1: pt(2.0, 836.7), control2: pt(6.3, 838.2))
        path.addCurve(to: pt(34.4, 818.0), control1: pt(17.7, 831.8), control2: pt(30.7, 820.8))
        path.addCurve(to: pt(14.0, 862.0), control1: pt(31.0, 825.3), control2: pt(17.4, 854.7))
        path.addCurve(to: pt(37.8, 836.5), control1: pt(18.0, 857.8), control2: pt(33.8, 840.8))
        path.addCurve(to: pt(29.0, 854.0), control1: pt(36.3, 839.4), control2: pt(30.5, 851.1))
        path.addCurve(to: pt(44.0, 839.5), control1: pt(31.5, 851.6), control2: pt(40.3, 844.8))
        path.addCurve(to: pt(51.0, 822.0), control1: pt(47.7, 834.2), control2: pt(47.6, 827.2))
        path.addCurve(to: pt(64.5, 808.0), control1: pt(54.4, 816.8), control2: pt(62.2, 810.3))
        path.addCurve(to: pt(58.0, 829.0), control1: pt(63.4, 811.5), control2: pt(57.8, 822.0))
        path.addCurve(to: pt(66.0, 850.0), control1: pt(58.2, 836.0), control2: pt(64.7, 846.5))
        path.addCurve(to: pt(71.0, 826.0), control1: pt(66.8, 846.0), control2: pt(66.8, 835.5))
        path.addCurve(to: pt(91.4, 793.1), control1: pt(75.2, 816.5), control2: pt(85.2, 803.7))
        path.addCurve(to: pt(108.0, 762.2), control1: pt(97.5, 782.4), control2: pt(90.7, 777.4))
        path.addCurve(to: pt(195.2, 702.0), control1: pt(125.3, 747.0), control2: pt(180.7, 712.0))
        path.addCurve(to: pt(223.3, 771.7), control1: pt(199.9, 713.6), control2: pt(221.4, 748.7))
        path.addCurve(to: pt(206.6, 840.2), control1: pt(225.2, 794.7), control2: pt(212.0, 811.3))
        path.addCurve(to: pt(190.5, 944.9), control1: pt(201.1, 869.1), control2: pt(195.1, 906.9))
        path.addCurve(to: pt(179.2, 1067.8), control1: pt(186.0, 982.8), control2: pt(181.8, 1030.3))
        path.addCurve(to: pt(175.0, 1170.0), control1: pt(176.6, 1105.3), control2: pt(166.5, 1136.0))
        path.addCurve(to: pt(230.0, 1272.0), control1: pt(183.5, 1204.0), control2: pt(220.8, 1255.0))
        path.addCurve(to: pt(212.2, 1244.5), control1: pt(227.0, 1267.4), control2: pt(215.2, 1249.1))
        path.addCurve(to: pt(241.0, 1598.0), control1: pt(217.0, 1303.4), control2: pt(235.0, 1529.8))
        path.addCurve(to: pt(248.1, 1653.6), control1: pt(247.0, 1666.2), control2: pt(246.6, 1637.7))
        path.addCurve(to: pt(250.0, 1693.6), control1: pt(249.6, 1669.5), control2: pt(252.6, 1684.8))
        path.addCurve(to: pt(232.4, 1706.5), control1: pt(247.4, 1702.4), control2: pt(235.3, 1704.3))
        path.addCurve(to: pt(232.4, 1711.5), control1: pt(232.4, 1707.3), control2: pt(232.4, 1710.7))
        path.addCurve(to: pt(406.0, 1702.0), control1: pt(261.3, 1709.9), control2: pt(370.5, 1702.7))
        path.addCurve(to: pt(445.5, 1707.2), control1: pt(441.5, 1701.3), control2: pt(432.5, 1704.4))
        path.addCurve(to: pt(484.0, 1719.4), control1: pt(458.5, 1710.1), control2: pt(471.4, 1713.6))
        path.addCurve(to: pt(521.2, 1742.2), control1: pt(496.6, 1725.2), control2: pt(509.2, 1732.7))
        path.addCurve(to: pt(555.6, 1776.2), control1: pt(533.1, 1751.7), control2: pt(544.7, 1763.6))
        path.addCurve(to: pt(587.0, 1818.0), control1: pt(566.6, 1788.8), control2: pt(579.8, 1803.4))
        path.addCurve(to: pt(599.0, 1864.0), control1: pt(594.2, 1832.6), control2: pt(597.0, 1856.3))
        path.addLine(to: pt(600.0, 1864.0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()

        // Inner subpath 1
        path.move(to: pt(500.0, 143.0))
        path.addCurve(to: pt(501.0, 154.0), control1: pt(501.3, 146.0), control2: pt(500.8, 152.2))
        path.addCurve(to: pt(483.0, 148.0), control1: pt(498.0, 153.0), control2: pt(488.8, 148.4))
        path.addCurve(to: pt(466.5, 151.8), control1: pt(477.2, 147.6), control2: pt(469.2, 151.2))
        path.addCurve(to: pt(486.0, 137.0), control1: pt(469.8, 149.3), control2: pt(481.6, 139.6))
        path.addCurve(to: pt(493.0, 136.0), control1: pt(490.4, 134.4), control2: pt(491.8, 136.2))
        path.addCurve(to: pt(500.0, 143.0), control1: pt(494.2, 137.2), control2: pt(498.7, 140.0))
        path.closeSubpath()

        // Inner subpath 2
        path.move(to: pt(494.0, 155.0))
        path.addCurve(to: pt(503.0, 164.0), control1: pt(495.5, 156.5), control2: pt(500.5, 159.8))
        path.addCurve(to: pt(509.0, 180.0), control1: pt(505.5, 168.2), control2: pt(507.7, 173.7))
        path.addCurve(to: pt(511.0, 202.0), control1: pt(510.3, 186.3), control2: pt(510.7, 198.3))
        path.addCurve(to: pt(501.0, 172.0), control1: pt(509.3, 197.0), control2: pt(505.2, 179.8))
        path.addCurve(to: pt(486.0, 155.0), control1: pt(496.8, 164.2), control2: pt(488.5, 157.8))
        path.addCurve(to: pt(494.0, 155.0), control1: pt(487.3, 155.0), control2: pt(492.7, 155.0))
        path.closeSubpath()

        // Inner subpath 3
        path.move(to: pt(508.0, 221.0))
        path.addCurve(to: pt(462.0, 285.0), control1: pt(500.3, 231.7), control2: pt(471.6, 269.6))
        path.addCurve(to: pt(450.7, 313.2), control1: pt(452.4, 300.4), control2: pt(453.9, 303.8))
        path.addCurve(to: pt(442.7, 341.1), control1: pt(447.5, 322.5), control2: pt(444.5, 332.0))
        path.addCurve(to: pt(440.0, 367.5), control1: pt(440.9, 350.1), control2: pt(439.9, 358.2))
        path.addCurve(to: pt(443.2, 396.6), control1: pt(440.1, 376.8), control2: pt(441.4, 385.9))
        path.addCurve(to: pt(451.0, 432.0), control1: pt(445.1, 407.4), control2: pt(441.4, 411.1))
        path.addCurve(to: pt(501.0, 522.0), control1: pt(460.6, 452.9), control2: pt(492.7, 507.0))
        path.addCurve(to: pt(478.0, 490.0), control1: pt(497.2, 516.7), control2: pt(495.8, 510.0))
        path.addCurve(to: pt(394.0, 401.9), control1: pt(460.2, 470.0), control2: pt(419.3, 428.0))
        path.addCurve(to: pt(326.0, 333.8), control1: pt(368.7, 375.9), control2: pt(339.7, 350.1))
        path.addCurve(to: pt(312.0, 304.0), control1: pt(312.3, 317.5), control2: pt(314.3, 309.0))
        path.addCurve(to: pt(320.0, 300.0), control1: pt(313.3, 303.3), control2: pt(318.7, 300.7))
        path.addCurve(to: pt(308.0, 284.5), control1: pt(318.0, 297.4), control2: pt(310.0, 287.1))
        path.addCurve(to: pt(321.6, 272.7), control1: pt(310.3, 282.5), control2: pt(319.3, 274.7))
        path.addCurve(to: pt(364.0, 289.0), control1: pt(328.7, 275.4), control2: pt(352.1, 288.2))
        path.addCurve(to: pt(393.2, 277.6), control1: pt(375.9, 289.8), control2: pt(382.9, 282.5))
        path.addCurve(to: pt(426.0, 260.0), control1: pt(403.6, 272.8), control2: pt(417.6, 268.6))
        path.addCurve(to: pt(443.5, 226.0), control1: pt(434.4, 251.4), control2: pt(440.6, 231.7))
        path.addCurve(to: pt(455.0, 238.0), control1: pt(445.4, 228.0), control2: pt(453.1, 234.7))
        path.addCurve(to: pt(454.9, 245.6), control1: pt(456.9, 241.3), control2: pt(455.0, 243.0))
        path.addCurve(to: pt(454.0, 253.5), control1: pt(454.7, 248.1), control2: pt(456.1, 250.6))
        path.addCurve(to: pt(442.0, 263.0), control1: pt(451.9, 256.4), control2: pt(444.0, 261.4))
        path.addCurve(to: pt(451.5, 262.0), control1: pt(443.6, 262.8), control2: pt(448.0, 264.5))
        path.addCurve(to: pt(463.0, 248.0), control1: pt(455.0, 259.5), control2: pt(461.1, 250.3))
        path.addCurve(to: pt(460.5, 272.0), control1: pt(462.6, 252.0), control2: pt(460.9, 268.0))
        path.addCurve(to: pt(472.6, 250.0), control1: pt(462.5, 268.3), control2: pt(464.7, 258.5))
        path.addCurve(to: pt(508.0, 221.0), control1: pt(480.5, 241.5), control2: pt(502.1, 225.8))
        path.closeSubpath()

        // Inner subpath 4
        path.move(to: pt(350.0, 453.0))
        path.addCurve(to: pt(454.0, 535.9), control1: pt(369.2, 468.6), control2: pt(436.7, 522.1))
        path.addCurve(to: pt(348.0, 646.2), control1: pt(436.3, 554.3), control2: pt(366.7, 624.7))
        path.addCurve(to: pt(342.0, 665.0), control1: pt(329.3, 667.7), control2: pt(342.4, 658.8))
        path.addCurve(to: pt(345.6, 683.6), control1: pt(341.6, 671.2), control2: pt(345.0, 680.5))
        path.addCurve(to: pt(292.1, 646.0), control1: pt(336.7, 677.3), control2: pt(303.2, 654.9))
        path.addCurve(to: pt(278.9, 630.2), control1: pt(281.0, 637.1), control2: pt(282.7, 635.7))
        path.addCurve(to: pt(269.6, 612.8), control1: pt(275.2, 624.6), control2: pt(271.7, 619.1))
        path.addCurve(to: pt(266.3, 592.2), control1: pt(267.5, 606.5), control2: pt(265.9, 600.1))
        path.addCurve(to: pt(272.1, 565.7), control1: pt(266.7, 584.4), control2: pt(267.7, 576.9))
        path.addCurve(to: pt(292.7, 525.2), control1: pt(276.5, 554.6), control2: pt(283.4, 541.5))
        path.addCurve(to: pt(328.0, 467.8), control1: pt(302.0, 508.9), control2: pt(320.4, 481.7))
        path.addCurve(to: pt(338.5, 442.0), control1: pt(335.6, 453.9), control2: pt(336.8, 446.3))
        path.addCurve(to: pt(350.0, 453.0), control1: pt(340.4, 443.8), control2: pt(330.8, 437.4))
        path.closeSubpath()

        // Inner subpath 5
        path.move(to: pt(504.0, 559.0))
        path.addCurve(to: pt(432.0, 630.3), control1: pt(492.0, 570.9), control2: pt(445.8, 613.0))
        path.addCurve(to: pt(421.4, 662.6), control1: pt(418.2, 647.6), control2: pt(424.0, 649.0))
        path.addCurve(to: pt(416.4, 711.8), control1: pt(418.8, 676.2), control2: pt(417.1, 691.9))
        path.addCurve(to: pt(417.0, 782.0), control1: pt(415.6, 731.7), control2: pt(418.9, 762.3))
        path.addCurve(to: pt(405.0, 830.0), control1: pt(415.1, 801.7), control2: pt(407.0, 822.0))
        path.addCurve(to: pt(412.0, 793.0), control1: pt(406.2, 823.8), control2: pt(410.8, 801.1))
        path.addCurve(to: pt(412.4, 781.6), control1: pt(413.2, 784.9), control2: pt(412.6, 786.7))
        path.addCurve(to: pt(411.2, 762.1), control1: pt(412.3, 776.4), control2: pt(413.1, 771.4))
        path.addCurve(to: pt(400.8, 725.4), control1: pt(409.2, 752.7), control2: pt(406.2, 740.4))
        path.addCurve(to: pt(379.0, 672.0), control1: pt(395.4, 710.4), control2: pt(383.0, 683.9))
        path.addCurve(to: pt(377.0, 654.0), control1: pt(375.0, 660.1), control2: pt(377.3, 657.0))
        path.addCurve(to: pt(394.3, 636.0), control1: pt(379.9, 651.0), control2: pt(379.3, 646.7))
        path.addCurve(to: pt(467.0, 590.0), control1: pt(409.3, 625.3), control2: pt(448.7, 602.8))
        path.addCurve(to: pt(504.0, 559.0), control1: pt(485.3, 577.2), control2: pt(497.8, 564.2))
        path.closeSubpath()

        // Inner subpath 6
        path.move(to: pt(396.0, 849.0))
        path.closeSubpath()

        // Inner subpath 7
        path.move(to: pt(376.0, 885.0))
        path.closeSubpath()

        // Inner subpath 8
        path.move(to: pt(372.0, 894.0))
        path.closeSubpath()

        // Inner subpath 9
        path.move(to: pt(366.0, 908.0))
        path.closeSubpath()

        // Inner subpath 10
        path.move(to: pt(362.0, 918.0))
        path.closeSubpath()

        // Inner subpath 11
        path.move(to: pt(360.0, 924.0))
        path.addCurve(to: pt(351.0, 966.0), control1: pt(358.5, 931.0), control2: pt(351.7, 909.5))
        path.addCurve(to: pt(355.7, 1263.1), control1: pt(350.3, 1022.5), control2: pt(352.6, 1186.2))
        path.addCurve(to: pt(369.6, 1427.2), control1: pt(358.8, 1340.0), control2: pt(363.2, 1390.1))
        path.addCurve(to: pt(394.0, 1485.5), control1: pt(376.0, 1464.3), control2: pt(389.8, 1473.4))
        path.addCurve(to: pt(395.0, 1500.0), control1: pt(398.2, 1497.6), control2: pt(394.8, 1497.6))
        path.addCurve(to: pt(392.0, 1486.5), control1: pt(394.5, 1497.8), control2: pt(392.5, 1488.8))
        path.addCurve(to: pt(360.0, 1466.4), control1: pt(386.7, 1483.2), control2: pt(367.2, 1475.5))
        path.addCurve(to: pt(348.9, 1431.9), control1: pt(352.8, 1457.3), control2: pt(352.8, 1447.4))
        path.addCurve(to: pt(336.6, 1373.4), control1: pt(345.0, 1416.4), control2: pt(340.9, 1395.4))
        path.addCurve(to: pt(322.6, 1300.0), control1: pt(332.2, 1351.4), control2: pt(327.5, 1322.8))
        path.addCurve(to: pt(307.1, 1236.6), control1: pt(317.7, 1277.2), control2: pt(312.2, 1256.3))
        path.addCurve(to: pt(291.9, 1181.8), control1: pt(301.9, 1216.9), control2: pt(295.6, 1200.8))
        path.addCurve(to: pt(285.1, 1123.0), control1: pt(288.3, 1162.9), control2: pt(284.2, 1143.3))
        path.addCurve(to: pt(297.0, 1059.9), control1: pt(285.9, 1102.6), control2: pt(290.0, 1081.4))
        path.addCurve(to: pt(327.0, 994.0), control1: pt(304.0, 1038.4), control2: pt(316.5, 1016.7))
        path.addCurve(to: pt(360.0, 924.0), control1: pt(337.5, 971.3), control2: pt(354.5, 935.7))
        path.closeSubpath()

        // Inner subpath 12
        path.move(to: pt(276.0, 1080.6))
        path.closeSubpath()

        // Inner subpath 13
        path.move(to: pt(272.0, 1087.0))
        path.closeSubpath()

        // Inner subpath 14
        path.move(to: pt(266.0, 1097.0))
        path.closeSubpath()

        // Inner subpath 15
        path.move(to: pt(260.0, 1107.0))
        path.closeSubpath()

        // Inner subpath 16
        path.move(to: pt(256.0, 1115.0))
        path.closeSubpath()

        // Inner subpath 17
        path.move(to: pt(250.0, 1130.0))
        path.closeSubpath()

        // Inner subpath 18
        path.move(to: pt(250.0, 1149.0))
        path.addCurve(to: pt(249.0, 1152.0), control1: pt(250.0, 1150.0), control2: pt(249.2, 1151.5))
        path.addCurve(to: pt(249.0, 1146.0), control1: pt(249.0, 1151.0), control2: pt(249.0, 1147.0))
        path.addCurve(to: pt(250.0, 1149.0), control1: pt(249.2, 1146.5), control2: pt(250.0, 1148.0))
        path.closeSubpath()

        // Inner subpath 19
        path.move(to: pt(254.7, 1159.5))
        path.closeSubpath()

        // Inner subpath 20
        path.move(to: pt(265.6, 1172.6))
        path.addCurve(to: pt(273.7, 1181.7), control1: pt(268.6, 1175.5), control2: pt(272.4, 1180.2))
        path.addCurve(to: pt(256.0, 1164.5), control1: pt(270.8, 1178.8), control2: pt(258.9, 1167.4))
        path.addCurve(to: pt(265.6, 1172.6), control1: pt(257.6, 1165.8), control2: pt(262.7, 1169.7))
        path.closeSubpath()

        // Inner subpath 21
        path.move(to: pt(280.7, 1189.5))
        path.closeSubpath()

        // Inner subpath 22
        path.move(to: pt(236.0, 1286.0))
        path.closeSubpath()

        // Inner subpath 23
        path.move(to: pt(242.0, 1297.9))
        path.closeSubpath()

        // Inner subpath 24
        path.move(to: pt(248.0, 1309.9))
        path.closeSubpath()

        // Inner subpath 25
        path.move(to: pt(252.0, 1318.0))
        path.closeSubpath()

        // Inner subpath 26
        path.move(to: pt(258.0, 1330.0))
        path.closeSubpath()

        // Inner subpath 27
        path.move(to: pt(276.0, 1368.0))
        path.closeSubpath()

        // Inner subpath 28
        path.move(to: pt(288.0, 1394.0))
        path.addCurve(to: pt(311.0, 1456.0), control1: pt(291.8, 1404.3), control2: pt(299.7, 1420.2))
        path.addCurve(to: pt(356.0, 1608.5), control1: pt(322.3, 1491.8), control2: pt(348.5, 1583.1))
        path.addCurve(to: pt(340.0, 1636.5), control1: pt(353.3, 1613.2), control2: pt(346.8, 1627.8))
        path.addCurve(to: pt(315.5, 1660.6), control1: pt(333.2, 1645.2), control2: pt(322.8, 1652.7))
        path.addCurve(to: pt(296.0, 1683.5), control1: pt(308.2, 1668.4), control2: pt(303.2, 1676.3))
        path.addCurve(to: pt(272.0, 1704.0), control1: pt(288.8, 1690.7), control2: pt(276.0, 1700.6))
        path.addCurve(to: pt(289.0, 1678.0), control1: pt(274.8, 1699.7), control2: pt(285.2, 1690.2))
        path.addCurve(to: pt(294.7, 1631.1), control1: pt(292.8, 1665.8), control2: pt(292.6, 1644.6))
        path.addCurve(to: pt(301.6, 1596.5), control1: pt(296.8, 1617.5), control2: pt(300.0, 1605.8))
        path.addCurve(to: pt(304.3, 1575.2), control1: pt(303.2, 1587.2), control2: pt(304.9, 1581.7))
        path.addCurve(to: pt(298.0, 1558.0), control1: pt(303.7, 1568.8), control2: pt(301.0, 1564.6))
        path.addCurve(to: pt(286.2, 1535.6), control1: pt(295.0, 1551.4), control2: pt(289.6, 1545.1))
        path.addCurve(to: pt(277.6, 1501.1), control1: pt(282.8, 1526.1), control2: pt(279.4, 1514.7))
        path.addCurve(to: pt(275.0, 1454.0), control1: pt(275.7, 1487.5), control2: pt(273.3, 1471.9))
        path.addCurve(to: pt(288.0, 1394.0), control1: pt(276.7, 1436.1), control2: pt(285.8, 1404.0))
        path.closeSubpath()

        // Inner subpath 29
        path.move(to: pt(388.0, 1522.0))
        path.addCurve(to: pt(381.0, 1560.0), control1: pt(386.8, 1528.3), control2: pt(382.2, 1553.7))
        path.addCurve(to: pt(381.0, 1538.0), control1: pt(381.0, 1556.3), control2: pt(379.8, 1544.3))
        path.addCurve(to: pt(388.0, 1522.0), control1: pt(382.2, 1531.7), control2: pt(386.8, 1524.7))
        path.closeSubpath()

        // Inner subpath 30
        path.move(to: pt(384.0, 1570.0))
        path.addCurve(to: pt(383.0, 1574.0), control1: pt(384.0, 1571.3), control2: pt(383.2, 1573.3))
        path.addCurve(to: pt(383.0, 1566.0), control1: pt(383.0, 1572.7), control2: pt(383.0, 1567.3))
        path.addCurve(to: pt(384.0, 1570.0), control1: pt(383.2, 1566.7), control2: pt(384.0, 1568.7))
        path.closeSubpath()

        // Inner subpath 31
        path.move(to: pt(386.0, 1582.0))
        path.closeSubpath()

        // Inner subpath 32
        path.move(to: pt(386.0, 1601.0))
        path.addCurve(to: pt(383.0, 1610.0), control1: pt(385.7, 1603.3), control2: pt(383.5, 1608.5))
        path.addCurve(to: pt(385.0, 1596.0), control1: pt(383.3, 1607.7), control2: pt(384.7, 1598.3))
        path.addCurve(to: pt(386.0, 1601.0), control1: pt(385.2, 1596.8), control2: pt(386.3, 1598.7))
        path.closeSubpath()

        // Inner subpath 33
        path.move(to: pt(311.3, 279.5))
        path.addCurve(to: pt(314.0, 290.0), control1: pt(311.8, 281.2), control2: pt(313.6, 288.2))
        path.addCurve(to: pt(321.5, 289.5), control1: pt(315.2, 289.9), control2: pt(320.2, 289.6))
        path.addCurve(to: pt(322.6, 283.4), control1: pt(321.7, 288.5), control2: pt(322.4, 284.4))
        path.addCurve(to: pt(318.0, 283.0), control1: pt(321.8, 283.3), control2: pt(318.8, 283.1))
        path.addCurve(to: pt(318.4, 288.0), control1: pt(318.1, 283.8), control2: pt(318.3, 287.2))
        path.addCurve(to: pt(311.3, 279.5), control1: pt(317.2, 286.6), control2: pt(312.5, 280.9))
        path.closeSubpath()

        // Inner subpath 34
        path.move(to: pt(462.0, 129.0))
        path.addCurve(to: pt(452.0, 139.5), control1: pt(460.3, 130.8), control2: pt(455.1, 132.7))
        path.addCurve(to: pt(443.5, 170.0), control1: pt(448.9, 146.3), control2: pt(444.9, 164.9))
        path.addCurve(to: pt(451.0, 162.0), control1: pt(444.8, 168.7), control2: pt(448.8, 166.7))
        path.addCurve(to: pt(457.0, 142.0), control1: pt(453.2, 157.3), control2: pt(454.2, 147.4))
        path.addCurve(to: pt(468.0, 129.6), control1: pt(459.8, 136.6), control2: pt(466.2, 131.7))
        path.addCurve(to: pt(462.0, 129.0), control1: pt(467.0, 129.5), control2: pt(463.0, 129.1))
        path.closeSubpath()

    }
}

struct SilhouetteShape: Shape {
    let side: EdgeSide

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        var rightPath = Path()
        CanonicalSilhouette.appendPath(to: &rightPath, in: rect, side: .right)
        guard side == .left else { return rightPath }

        let mirror = CGAffineTransform(
            a: -1,
            b: 0,
            c: 0,
            d: 1,
            tx: rect.minX + rect.maxX,
            ty: 0
        )
        return rightPath.applying(mirror)
    }
}
