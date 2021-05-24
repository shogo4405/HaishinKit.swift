import Foundation
import XCTest

@testable import HaishinKit

final class MP4BoxTests: XCTestCase {
    func testMP4FileTypeBox() {
        let src = MP4FileTypeBox(
            size: 0,
            type: "ftyp",
            offset: 0, children: [],
            majorBrand: MP4Util.uint32("mp4a"),
            minorVersion: 512,
            compatibleBrands: [MP4Util.uint32("mp4a"), MP4Util.uint32("msdh")]
        )

        var dst = MP4FileTypeBox()
        dst.data = src.data

        XCTAssertEqual(src.type, dst.type)
        XCTAssertEqual(src.minorVersion, dst.minorVersion)
        XCTAssertEqual(src.majorBrand, dst.majorBrand)
        XCTAssertEqual(src.compatibleBrands, dst.compatibleBrands)
    }
    
    func testMP4MovieHeaderBox() {
        let src = MP4MovieHeaderBox(
            size: 108,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            creationTime: 2082844800,
            modificationTime: 3488636519,
            timeScale: 1000,
            duration: 64896,
            rate: 65536,
            volume: MP4MovieHeaderBox.volume,
            matrix: [65536,0,0,0,65536,0,0,0,1073741824],
            nextTrackID: 3
        )

        var dst = MP4MovieHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.creationTime, dst.creationTime)
        XCTAssertEqual(src.modificationTime, dst.modificationTime)
        XCTAssertEqual(src.timeScale, dst.timeScale)
        XCTAssertEqual(src.duration, dst.duration)
        XCTAssertEqual(src.rate, dst.rate)
        XCTAssertEqual(src.volume, dst.volume)
        XCTAssertEqual(src.matrix, dst.matrix)
        XCTAssertEqual(src.nextTrackID, dst.nextTrackID)
    }

    func testMP4SegmentIndexBox() {
        let src = MP4SegmentIndexBox(
            size: 52,
            offset: 0,
            children: [],
            version: 1,
            referenceID: 1,
            timescale: 15360,
            earliestPresentationTime: 0,
            firstOffset: 52,
            references: [
                MP4SegmentIndexBox.Reference(
                    type: false,
                    size: 530176,
                    subsegmentDuration: 92160,
                    startsWithSap: true,
                    sapType: 0,
                    sapDeltaTime: 0
                )
            ]
        )

        var dst = MP4SegmentIndexBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.referenceID, dst.referenceID)
        XCTAssertEqual(src.timescale, dst.timescale)
        XCTAssertEqual(src.earliestPresentationTime, dst.earliestPresentationTime)
        XCTAssertEqual(src.firstOffset, dst.firstOffset)
        XCTAssertEqual(src.references.first, dst.references.first)
    }

    func testMP4MovieFragmentHeaderBox() {
        let src = MP4MovieFragmentHeaderBox(
            size: 16,
            offset: 0,
            children: [],
            sequenceNumber: 1
        )

        var dst = MP4MovieFragmentHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.sequenceNumber, dst.sequenceNumber)
    }

    func testMP4TrackFragmentBaseMediaDecodeTimeBox() {
        let src = MP4TrackFragmentBaseMediaDecodeTimeBox(
            size: 20,
            offset: 0,
            children: [],
            version: 1,
            baseMediaDecodeTime: 0
        )
        
        var dst = MP4TrackFragmentBaseMediaDecodeTimeBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.baseMediaDecodeTime, dst.baseMediaDecodeTime)
    }

    func testMP4TrackRunBox() {
        let src = MP4TrackRunBox(
            size: 36,
            offset: 0,
            children: [],
            version: 0,
            flags: 1537,
            dataOffset: 1676,
            firstSampleFlags: nil,
            samples:[
                MP4TrackRunBox.Sample(duration: nil, size: 43, flags: 16842752, compositionTimeOffset: nil),
                MP4TrackRunBox.Sample(duration: nil, size: 23087, flags: 33554432, compositionTimeOffset: nil),
            ]
        )

        var dst = MP4TrackRunBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.dataOffset, dst.dataOffset)
        XCTAssertEqual(src.firstSampleFlags, dst.firstSampleFlags)
        XCTAssertEqual(src.samples.first, dst.samples.first)
    }

    func testMP4HandlerBox() {
        let src = MP4HandlerBox(
            size: 33,
            offset: 0,
            version: 0,
            flags: 0,
            children: [],
            handlerType: MP4Util.uint32("mdlr"),
            name: ""
        )

        var dst = MP4HandlerBox()
        dst.data = src.data
        
        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.handlerType, dst.handlerType)
        XCTAssertEqual(src.name, dst.name)
    }

    func testMP4TrackExtendsBox() {
        let src = MP4TrackExtendsBox(
            size: 32,
            offset: 0,
            version: 0,
            flags: 0,
            children: [],
            trackID: 1,
            defaultSampleDescriptionIndex: 1,
            defaultSampleDuration: 0,
            defaultSampleSize: 0,
            defaultSampleFlags: 0
        )
        
        var dst = MP4TrackExtendsBox()
        dst.data = src.data
        
        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.trackID, dst.trackID)
        XCTAssertEqual(src.defaultSampleDescriptionIndex, dst.defaultSampleDescriptionIndex)
        XCTAssertEqual(src.defaultSampleDuration, dst.defaultSampleDuration)
        XCTAssertEqual(src.defaultSampleSize, dst.defaultSampleSize)
        XCTAssertEqual(src.defaultSampleFlags, dst.defaultSampleFlags)
    }

    func testMP4SoundMediaHeaderBox() {
        let src = MP4SoundMediaHeaderBox(
            size: 16,
            offset: 0,
            version: 0,
            flags: 0,
            children: [],
            balance: 0
        )
        
        var dst = MP4SoundMediaHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.balance, dst.balance)
    }

    func testMP4VideoMediaHeaderBox() {
        let src = MP4VideoMediaHeaderBox(
            size: 20,
            offset: 0,
            version: 0,
            flags: 0,
            children: [],
            graphicsMode: 0,
            opcolor: [0, 0, 0]
        )

        var dst = MP4VideoMediaHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.graphicsMode, dst.graphicsMode)
        XCTAssertEqual(src.opcolor, dst.opcolor)
    }

    func testMP4MediaHeaderBox() {
        let src = MP4MediaHeaderBox(
            size: 32,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            creationTime: 2082844800,
            modificationTime: 2082844800,
            timeScale: 15360,
            duration: 996352,
            language: [21, 14, 4]
        )

        var dst = MP4MediaHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.creationTime, dst.creationTime)
        XCTAssertEqual(src.modificationTime, dst.modificationTime)
        XCTAssertEqual(src.timeScale, dst.timeScale)
        XCTAssertEqual(src.modificationTime, dst.modificationTime)
        XCTAssertEqual(src.duration, dst.duration)
        XCTAssertEqual(src.language, dst.language)
    }

    func testMP4TrackHeaderBox() {
        let src = MP4TrackHeaderBox(
            size: 92,
            offset: 0,
            children: [],
            version: 0,
            flags: 15,
            creationTime: 2082844800,
            modificationTime: 2082844800,
            trackID: 2,
            duration: 64896,
            layer: 0,
            alternateGroup: 1,
            volume: MP4TrackHeaderBox.volume,
            matrix: [65536, 0, 0, 0, 65536, 0, 0, 0, 1073741824],
            width: 0,
            height: 0
        )

        var dst = MP4TrackHeaderBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.creationTime, dst.creationTime)
        XCTAssertEqual(src.modificationTime, dst.modificationTime)
        XCTAssertEqual(src.trackID, dst.trackID)
        XCTAssertEqual(src.duration, dst.duration)
        XCTAssertEqual(src.layer, dst.layer)
        XCTAssertEqual(src.alternateGroup, dst.alternateGroup)
        XCTAssertEqual(src.volume, dst.volume)
        XCTAssertEqual(src.matrix, dst.matrix)
        XCTAssertEqual(src.width, dst.width)
        XCTAssertEqual(src.height, dst.height)
    }

    func testMP4EditListBox() {
        let src = MP4EditListBox(
            size: 28,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            entries: [
                .init(segmentDuration: 0, mediaTime: 0, mediaRateInteger: 1, mediaRateFraction: 0)
            ])

        var dst = MP4EditListBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries.first, dst.entries.first)
    }

    func testMP4TimeToSampleBox() {
        let src = MP4TimeToSampleBox(
            size: 24,
            offset: 0,
            children: [],
            entries: [
                .init(sampleCount: 973, sampleDelta: 1024)
            ]
        )

        var dst = MP4TimeToSampleBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries.first, dst.entries.first)
    }

    func testMP4SyncSampleBox() {
        let src = MP4SyncSampleBox(
            size: 68,
            offset: 0,
            children: [],
            entries: [1, 127, 196, 242, 327, 355, 387, 419, 485, 632, 657, 782, 844]
        )

        var dst = MP4SyncSampleBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries, dst.entries)
    }

    func testMP4SampleToChunkBox() {
        let src = MP4SampleToChunkBox(
            size: 28,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            entries: [
                .init(firstChunk: 1, samplesPerChunk: 1, sampleDescriptionIndex: 1)
            ]
        )

        var dst = MP4SampleToChunkBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries, dst.entries)
    }

    func testMP4SampleSizeBox() {
        let src = MP4SampleSizeBox(
            size: 3912,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            entries: [22696,807,660,1391,1208,2403,2928,2076,3443,2264,3319,3855,2698,3828,2992,3989,3800,2804,3703,3010,3733,4026,3159,4437,3266,4579,4355,3365,4455,3237,4092,3952,2951,3826,2992,3551,4098,2701,3980,2796,3828,3879,2803,3977,2182,3925,3781,1929,3716,1216,2886,1743,1150,1887,886,730,704,499,960,552,928,1150,1007,2132,1628,2240,2223,1475,1980,1047,1327,1651,1033,1450,865,1723,1042,1164,2254,1495,2591,2991,2068,2722,1785,1603,1878,1236,1260,536,1660,1526,1200,1426,1181,2021,2514,1559,2736,1525,2519,3123,1763,2932,1583,2585,2836,1757,2640,1742,2916,3592,2318,3535,1850,3146,3063,2002,2513,1541,2283,2598,1408,2059,1196,1413,10807,120,122,78,89,74,70,98,109,204,308,171,358,174,439,401,263,486,309,506,541,370,619,415,736,929,714,1149,721,987,1051,670,1103,714,1176,1208,933,1526,1040,1291,1203,702,902,660,827,946,639,741,493,605,529,369,359,248,393,331,249,410,358,542,521,411,515,349,553,566,323,394,180,14347,881,1055,1906,1250,1345,1710,1124,1621,831,1283,1701,841,1044,1008,1569,1053,925,1453,1039,1675,1252,775,1081,567,676,681,587,1129,1081,1629,2054,1578,1979,1293,2314,2333,1415,1695,1144,1426,1279,762,865,443,403,26914,312,515,354,597,1076,955,1439,687,1207,1348,905,1702,1518,1964,2254,1379,2157,1703,2730,2402,1745,2745,1564,1886,2383,2006,2557,1433,2368,2764,1844,2204,1991,3151,2706,2498,3832,2596,2681,3440,3328,3634,2494,3912,4611,2584,3191,2523,3926,4067,2805,4005,2976,4041,4267,2750,4043,2226,2529,2139,1492,2318,1643,2673,3106,2266,3624,2175,2459,2079,1982,3421,2174,3225,3809,3005,5234,3639,5454,4871,2705,3828,2118,2311,19192,114,281,280,359,304,257,343,214,395,399,355,364,242,383,347,254,417,251,540,461,199,438,214,262,282,141,201,24852,310,469,296,476,338,620,722,521,860,537,1036,1146,854,1253,841,1234,1267,849,1283,879,1259,1194,652,1090,697,990,755,454,468,212,175,16165,1149,2235,1492,2053,2246,1921,2565,1352,2162,2310,1670,2235,1952,4094,5151,3551,5556,3694,5402,6104,3940,6302,4323,6238,5332,2717,3037,1918,3115,2886,1157,24668,1735,3353,4516,3263,6544,4547,5610,5889,4152,6067,4442,5576,5172,3805,6008,4571,6087,7095,4766,7069,4517,6317,7328,5464,6979,4782,6514,7238,4960,6212,4536,5929,6345,4571,6452,4123,6120,6331,4516,5956,4215,5533,5215,3783,5822,4496,6278,6404,4039,5940,4210,6090,5173,3073,5206,3484,5543,5375,3129,5041,3261,4808,4182,2122,2245,11744,943,1628,1460,1803,1733,2363,2717,1996,2307,2065,2800,2809,2171,2831,2084,3109,3061,2121,2928,2212,2589,2306,1706,2198,1618,2222,2348,1645,2011,1505,2259,2120,1766,2112,1868,3326,3328,2373,3881,2526,3227,3319,2094,3224,1757,2979,2418,1397,2533,1180,1677,1407,891,847,766,1040,1562,928,1504,1319,1222,871,618,703,438,657,506,303,373,290,266,271,198,191,208,263,258,218,276,274,249,223,142,297,323,614,1456,1354,1761,1308,1633,1183,656,627,412,601,1008,808,1296,832,1110,1760,1412,2020,1127,1731,1534,925,982,515,836,1500,1230,2082,1498,2477,1922,955,909,504,484,393,242,289,197,273,257,195,284,195,319,457,551,777,701,1015,966,635,1084,661,828,641,248,186,88,43,23087,166,955,763,1280,1336,759,1192,849,2186,1604,1162,1950,1232,1712,1718,1057,1483,674,1006,764,387,539,182,128,20018,113,94,123,245,767,992,1557,1220,1582,1189,451,593,261,319,268,148,321,375,540,584,339,658,742,1407,1845,1220,1182,429,531,584,491,550,302,420,272,236,190,134,132,151,152,237,378,1412,1993,1561,1269,540,829,849,662,877,657,1213,1457,1125,1541,1160,1556,1792,1117,1563,1211,1966,2130,1407,2333,1537,2346,2426,1768,2455,1593,2559,2630,1736,2510,1585,2521,2018,1363,2079,1448,1905,1989,1255,1436,966,1289,1222,765,1064,737,959,1099,802,1055,876,910,758,674,673,409,672,480,454,802,522,522,677,642,643,690,618,702,526,554,389,384,402,378,363,287,337,27204,672,1294,996,1280,1355,1004,1541,1072,1730,1687,1263,1961,1317,1882,3030,1246,1752,1294,1805,1768,1105,1505,1046,1459,1689,1642,3666,2753,4758,10875,8893,9800,8291,7112,3692,1569,1762,1469,1618,1542,1168,1559,1231,1524,1406,1014,1353,870,1180,1107,722,943,671,920,787,623,800,558,648,607,277,13855,1100,1770,2017,1317,1830,1328,2274,2578,2127,2662,1670,2310,2530,2045,2908,1989,2519,2601,1734,2627,2148,3210,3510,2483,3618,3370,5139,3691,2899,3801,3229,4251,3970,2792,3365,2206,3024,2374,1806,2534,1623,2201,2635,1762,2631,2481,2399,1907,2087,1621,1423,1824,1362,1152,2260,2494,2648,5012,2744,3392,2213,2685,2041,1382,1398,1083,1872,4516,3367,4995,3732,3853,3064,2443,2256,1986,2114,1712,1633,1953,1212,1615,1503,927,1483,816,1924,3900,2562,4705,3733,4362,3468,2535,2581,1926,1819,1808,1617,1565,1584,1649,1481,1554,1603,1088,1713,2952,2278,5628,2950,3912,3429,2159,2923,1571,1983,2275,1844,3995,2854,3533,4255,3464,4922,3025,3845,3366,2207]
        )
        
        var dst = MP4SampleSizeBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries, dst.entries)
    }

    func testMP4ChunkOffsetBox() {
        let src = MP4ChunkOffsetBox(
            size: 3912,
            offset: 0,
            children: [],
            version: 0,
            flags: 0,
            entries: [48,23755,27608,31188,35606,39823,46234,52161,57242,63815,69094,75354,82214,87871,95643,101475,108404,114935,120469,127027,132905,139545,147442,153587,160998,167264,174874,182276,188754,196376,203878,211185,218264,224322,231227,237288,243953,251147,257913,264928,270801,277768,284782,290691,297775,303021,311035,317809,322859,329603,333793,339649,344388,348766,354861,359083,363134,366982,370551,374635,378109,381919,386886,391079,396291,401054,406297,411444,415828,420764,426202,430958,435877,440119,445063,449387,454477,458828,464739,470333,475079,480950,487078,492178,497962,502776,508392,513411,517725,522046,525569,530208,534741,538885,544174,548284,553278,558766,563290,569007,573391,578718,585795,590533,596408,600867,606227,612414,617498,623130,628664,634335,640811,646081,652543,657465,663546,669950,676570,681666,685726,690577,695816,699934,704749,708748,714184,728390,731840,734973,738194,741650,745381,749207,754367,758364,762367,765964,769051,772342,775468,778818,782931,785990,789693,792874,796294,799792,803253,806801,810536,814209,818215,821743,825587,829267,833137,837133,842342,846884,850965,855130,859226,862923,867156,870907,876022,880314,883981,887909,892040,896237,900471,904376,910028,914153,918309,922750,926694,930303,933737,937393,941945,945058,948332,951411,954564,957671,961197,964712,968979,972352,975692,978727,981787,984576,1001893,1005389,1009940,1014862,1019217,1023605,1028641,1033296,1038039,1042077,1048022,1052970,1056798,1060752,1064799,1069518,1074268,1078338,1084085,1088405,1093228,1097739,1102168,1106577,1110320,1114363,1119552,1123289,1127738,1131657,1135898,1140419,1144422,1148791,1153398,1158174,1163228,1167545,1172155,1176301,1180852,1185113,1189879,1193815,1197384,1201005,1231083,1234693,1238279,1241617,1246118,1250523,1254684,1259193,1263077,1267519,1272115,1276209,1282302,1287276,1292411,1297817,1302458,1307785,1312695,1318607,1325792,1331087,1337538,1342903,1348129,1353513,1358295,1364070,1369601,1375041,1381094,1385974,1390941,1395610,1401624,1407128,1413096,1420028,1425504,1430937,1437137,1443139,1449461,1454575,1462112,1469929,1475541,1481521,1486882,1493646,1500909,1506991,1515246,1521336,1528270,1535231,1540930,1548153,1553654,1559616,1565914,1570581,1576040,1581299,1587465,1593732,1599181,1605806,1612204,1617865,1623082,1628381,1634849,1640032,1646131,1652757,1659809,1668274,1675326,1684464,1693016,1699315,1706822,1712219,1718464,1740502,1743915,1747133,1750127,1753267,1756281,1759236,1763382,1766469,1769521,1772512,1775474,1778389,1781146,1784182,1788202,1791536,1794702,1797699,1801032,1804513,1807834,1811456,1816332,1820010,1823617,1827146,1830670,1858766,1862180,1865811,1870583,1874475,1878162,1882201,1886263,1890172,1894417,1898498,1904062,1908172,1911978,1916094,1919763,1923739,1927738,1931248,1936234,1939652,1943815,1947990,1951383,1955310,1958869,1962800,1967650,1971171,1974700,1977955,1981131,2000444,2004777,2010353,2016353,2021739,2027586,2033030,2039030,2043807,2049267,2054769,2060672,2066159,2071303,2078501,2086912,2093584,2102140,2108587,2117992,2126943,2133779,2142977,2150186,2159227,2167310,2173038,2180119,2185156,2191221,2197149,2201427,2229020,2233433,2239494,2247907,2254003,2263649,2271325,2279827,2288629,2295707,2304822,2313389,2322202,2330715,2337770,2347066,2354883,2364326,2374718,2383995,2394408,2402288,2411881,2422412,2431407,2441917,2449919,2460869,2471430,2479517,2488624,2496261,2505242,2514659,2522083,2532396,2539322,2548307,2557594,2565071,2573840,2580849,2589166,2598210,2604674,2613250,2620665,2629653,2638881,2645738,2654727,2662868,2671833,2679991,2686134,2694501,2701050,2709850,2718291,2725736,2734005,2740328,2748262,2755898,2761300,2766888,2782179,2787437,2792370,2797277,2802345,2807437,2813041,2819034,2824334,2830886,2836289,2842257,2848103,2853252,2859095,2864231,2870286,2877018,2881839,2887691,2892674,2897998,2903007,2907377,2912531,2917962,2923005,2928364,2932781,2937665,2942244,2947349,2952439,2958146,2963594,2968534,2975025,2981529,2987282,2994287,3000086,3007538,3014009,3019367,3025779,3030693,3036889,3042461,3046915,3053590,3057814,3062525,3067131,3071061,3074969,3078798,3082968,3088759,3092936,3097968,3102785,3107432,3111685,3115660,3119632,3124298,3127987,3131570,3134819,3138053,3141091,3144088,3147078,3150971,3153972,3157078,3160277,3163519,3166689,3169997,3173396,3177789,3181165,3184497,3188000,3191569,3195424,3200077,3204633,3210640,3215116,3219857,3224097,3227848,3231564,3235012,3238640,3243685,3247508,3251838,3255666,3259784,3264513,3268865,3273875,3278962,3283594,3287632,3291886,3296058,3299394,3303057,3307481,3312921,3318564,3323399,3329109,3333876,3337787,3341590,3345030,3349330,3352715,3355923,3359184,3362411,3365818,3369222,3372526,3376989,3380323,3383797,3387359,3391057,3394938,3398769,3402887,3408089,3411909,3416008,3419798,3423766,3427628,3431094,3434368,3438684,3441778,3468015,3471346,3475467,3479473,3484166,3488916,3493962,3498370,3502317,3507481,3512084,3516284,3521196,3525327,3530856,3535415,3539314,3543517,3547011,3550885,3554536,3557776,3562354,3565622,3568561,3591694,3595036,3598263,3601513,3604813,3609628,3613589,3618208,3622493,3627079,3631330,3634801,3638436,3642805,3646193,3649376,3652585,3656062,3659597,3663201,3666723,3671001,3674255,3677472,3681391,3685751,3689670,3693798,3697290,3701811,3705545,3709314,3713322,3717076,3720980,3724796,3728751,3734036,3737442,3740753,3744068,3747419,3750933,3754560,3759041,3765159,3769767,3774107,3777750,3781904,3786152,3790171,3794645,3800020,3804754,3809647,3814105,3818804,3823064,3827603,3832438,3837565,3842139,3846360,3851083,3855667,3859616,3864504,3868323,3873692,3878347,3882383,3887251,3891280,3896260,3901605,3906383,3912731,3917088,3922811,3928207,3932806,3938035,3942920,3948321,3954505,3958846,3963564,3967937,3972593,3977423,3981711,3986239,3991396,3995724,4000582,4005279,4010106,4014511,4019124,4023446,4028545,4032278,4035680,4039419,4042924,4046402,4050150,4053630,4058140,4061720,4065285,4068798,4072346,4075813,4079292,4082614,4086971,4090209,4093421,4096786,4100177,4103518,4106827,4110184,4141430,4145202,4149657,4153756,4158072,4162377,4166226,4170782,4175603,4180219,4184751,4188914,4193654,4197756,4202347,4208173,4213281,4217977,4222378,4227043,4231849,4235925,4240595,4244912,4250675,4255547,4260227,4266941,4272787,4280624,4294558,4306539,4321007,4333000,4344012,4351307,4356696,4362511,4367971,4373342,4379753,4384221,4389338,4393802,4398082,4402328,4406121,4410029,4414318,4417999,4421737,4424888,4428383,4431268,4434645,4437774,4441429,4444470,4447317,4450435,4453601,4456650,4473340,4477329,4483023,4488155,4492660,4497508,4501837,4507213,4512874,4518064,4524951,4530319,4536169,4542580,4548523,4554994,4560517,4566339,4573597,4579271,4585725,4591587,4598453,4605780,4611892,4618855,4626654,4635460,4642354,4648612,4655451,4661390,4668108,4674619,4681013,4687388,4692523,4698407,4703555,4708162,4713600,4718173,4724036,4729809,4734762,4740580,4746109,4751242,4755968,4760751,4766095,4770105,4774453,4778330,4782048,4787013,4792320,4797881,4806721,4812416,4818832,4824186,4829976,4835078,4839555,4844108,4849467,4854582,4862554,4869512,4877961,4885198,4892552,4898899,4905760,4911288,4916602,4921993,4927043,4931889,4936942,4941263,4947072,4951637,4955717,4960268,4964118,4969011,4975718,4981121,4989574,4996023,5003056,5009311,5014701,5020101,5024911,5029711,5035564,5040329,5045116,5049907,5054720,5059392,5064175,5068920,5074319,5079525,5086103,5091649,5100527,5106784,5114004,5120722,5127301,5133561,5138318,5143330,5148516,5153278,5160141,5165893,5173216,5180163,5186338,5193998,5199729,5206376,5212564,5217681]
        )
        
        var dst = MP4ChunkOffsetBox()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.version, dst.version)
        XCTAssertEqual(src.flags, dst.flags)
        XCTAssertEqual(src.entries, dst.entries)
    }

    func testMP4AudioSampleEntry() {
        let src = MP4AudioSampleEntry(
            size: 36,
            type: "mp4a",
            offset: 0,
            children: [],
            dataReferenceIndex: 1,
            channelCount: 2,
            sampleSize: 16,
            sampleRate: 48000
        )
        
        var dst = MP4AudioSampleEntry()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.dataReferenceIndex, dst.dataReferenceIndex)
        XCTAssertEqual(src.channelCount, dst.channelCount)
        XCTAssertEqual(src.sampleSize, dst.sampleSize)
        XCTAssertEqual(src.sampleRate, dst.sampleRate)
    }

    func testMP4VisualSampleEntry() {
        let src = MP4VisualSampleEntry(
            size: 54,
            type: "avc1",
            offset: 0,
            children: [],
            dataReferenceIndex: 1,
            width: 320,
            height: 240,
            hSolution: MP4VisualSampleEntry.hSolution,
            vSolution: MP4VisualSampleEntry.vSolution,
            frameCount: 1,
            compressorname: "",
            depth: 24
        )
    
        var dst = MP4VisualSampleEntry()
        dst.data = src.data

        XCTAssertEqual(src.size, dst.size)
        XCTAssertEqual(src.dataReferenceIndex, dst.dataReferenceIndex)
        XCTAssertEqual(src.width, dst.width)
        XCTAssertEqual(src.height, dst.height)
        XCTAssertEqual(src.hSolution, dst.hSolution)
        XCTAssertEqual(src.vSolution, dst.vSolution)
        XCTAssertEqual(src.frameCount, dst.frameCount)
        XCTAssertEqual(src.compressorname, dst.compressorname)
        XCTAssertEqual(src.depth, dst.depth)
    }
}
