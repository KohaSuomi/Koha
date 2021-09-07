[% PROCESS OKMGroupStatisticsAsHtml libraryGroups=libraryGroups %]
[% BLOCK OKMGroupStatisticsAsHtml #REQUIRES libraryGroups %]
    <table>
    [% headerPrinted = 0 %]
    [% FOREACH groupcode IN libraryGroups.keys.sort %]
    [%  libraryGroup = libraryGroups.$groupcode
        statistics = libraryGroup.getStatistics() %]

        [% UNLESS headerPrinted %]
            [% PROCESS OKMGroupStatisticsHeaderAsHtml statistics=statistics %]
            [% headerPrinted = 1 %]
        [% END %]
        <tr>
            [% PROCESS OKMGroupStatisticsContentAsHtml statistics=statistics %]
        </tr>
    [% END #FOREACH libraryGroups.keys.sort %]
    </table>
[% END #BLOCK OKMGroupStatisticsAsHtml %]

[% BLOCK OKMGroupStatisticsHeaderAsHtml #REQUIRES statistics %]
    <thead><tr>
        [% FOREACH statKey IN statistics.printOrder %]
            <th>
            [% SWITCH statKey %]
            [% CASE 'branchCategory' %]
                Branch category
            [% CASE 'collection' %]
                Collection
            [% CASE 'collectionBooksTotal' %]
                Collection <em>books</em> total
            [% CASE 'collectionBooksFinnish' %]
                Collection <em>books</em> Finnish
            [% CASE 'collectionBooksSwedish' %]
                Collection <em>books</em> Swedish
            [% CASE 'collectionBooksOtherLanguage' %]
                Collection <em>books</em> other languages
            [% CASE 'collectionBooksFictionAdult' %]
                Collection <em>books</em> fiction adult
            [% CASE 'collectionBooksFictionJuvenile' %]
                Collection <em>books</em> fiction juvenile
            [% CASE 'collectionBooksNonFictionAdult' %]
                Collection <em>books</em> non-fiction adult
            [% CASE 'collectionBooksNonFictionJuvenile' %]
                Collection <em>books</em> non-fiction juvenile
            [% CASE 'collectionSheetMusicAndScores' %]
                Collection <em>sheet music and scores</em>
            [% CASE 'collectionMusicalRecordings' %]
                Collection <em>musical recordings</em>
            [% CASE 'collectionOtherRecordings' %]
                Collection <em>other recordings</em>
            [% CASE 'collectionVideos' %]
                Collection <em>videos</em>
            [% CASE 'collectionCDROMs' %]
                Collection <em>CD-ROMs</em>
            [% CASE 'collectionDVDsAndBluRays' %]
                Collection <em>DVDs and Blu-rays</em>
            [% CASE 'collectionOther' %]
                Collection <em>other</em>
            [% CASE 'acquisitions' %]
                Acquisitions
            [% CASE 'acquisitionsBooksTotal' %]
                Acquisitions <em>Books</em> total
            [% CASE 'acquisitionsBooksFinnish' %]
                Acquisitions <em>Books</em> Finnish
            [% CASE 'acquisitionsBooksSwedish' %]
                Acquisitions <em>Books</em> Swedish
            [% CASE 'acquisitionsBooksOtherLanguage' %]
                Acquisitions <em>Books</em> other languages
            [% CASE 'acquisitionsBooksFictionAdult' %]
                Acquisitions <em>Books</em> fiction adult
            [% CASE 'acquisitionsBooksFictionJuvenile' %]
                Acquisitions <em>Books</em> fiction juvenile
            [% CASE 'acquisitionsBooksNonFictionAdult' %]
                Acquisitions <em>Books</em> non-fiction adult
            [% CASE 'acquisitionsBooksNonFictionJuvenile' %]
                Acquisitions <em>Books</em> non-fiction juvenile
            [% CASE 'acquisitionsSheetMusicAndScores' %]
                Acquisitions <em>sheet music and scores</em>
            [% CASE 'acquisitionsMusicalRecordings' %]
                Acquisitions <em>musical recordings</em>
            [% CASE 'acquisitionsOtherRecordings' %]
                Acquisitions <em>other recordings</em>
            [% CASE 'acquisitionsVideos' %]
                Acquisitions <em>videos</em>
            [% CASE 'acquisitionsCDROMs' %]
                Acquisitions <em>CD-ROMs</em>
            [% CASE 'acquisitionsDVDsAndBluRays' %]
                Acquisitions <em>DVDs and Blu-rays</em>
            [% CASE 'acquisitionsOther' %]
                Acquisitions <em>other</em>
            [% CASE 'issues' %]
                Issues
            [% CASE 'issuesBooksTotal' %]
                Issues <em>books</em> total
            [% CASE 'issuesBooksFinnish' %]
                Issues <em>books</em> Finnish
            [% CASE 'issuesBooksSwedish' %]
                Issues <em>books</em> Swedish
            [% CASE 'issuesBooksOtherLanguage' %]
                Issues <em>books</em> other languages
            [% CASE 'issuesBooksFictionAdult' %]
                Issues <em>books</em> fiction adult
            [% CASE 'issuesBooksFictionJuvenile' %]
                Issues <em>books</em> fiction juvenile
            [% CASE 'issuesBooksNonFictionAdult' %]
                Issues <em>books</em> non-fiction adult
            [% CASE 'issuesBooksNonFictionJuvenile' %]
                Issues <em>books</em> non-fiction juvenile
            [% CASE 'issuesSheetMusicAndScores' %]
                Issues <em>sheet music and scores</em>
            [% CASE 'issuesMusicalRecordings' %]
                Issues <em>musical recordings</em>
            [% CASE 'issuesOtherRecordings' %]
                Issues <em>other recordings</em>
            [% CASE 'issuesVideos' %]
                Issues <em>videos</em>
            [% CASE 'issuesCDROMs' %]
                Issues <em>CD-ROMs</em>
            [% CASE 'issuesDVDsAndBluRays' %]
                Issues <em>DVDs and Blu-rays</em>
            [% CASE 'issuesOther' %]
                Issues <em>other</em>
            [% CASE 'newspapers' %]
                Newspapers
            [% CASE 'magazines' %]
                Magazines
            [% CASE 'discards' %]
                Discards
            [% CASE 'activeBorrowers' %]
                Active borrowers
            [% CASE 'expenditureAcquisitions' %]
                Expenditure acquisitions
            [% CASE 'expenditureAcquisitionsBooks' %]
                Expenditure acquisitions books
            [% CASE %]
                [% statKey %]
            [% END #SWITCH stat %]
            </th>
        [% END #FOREACH statistics.printOrder %]
    </thead></tr>
[% END #BLOCK OKMGroupStatisticsHeaderAsHtml %]

[% BLOCK OKMGroupStatisticsContentAsHtml #REQUIRES statistics %]
    [% FOREACH statKey IN statistics.printOrder %]
        <td>
            [% statistics.$statKey %]
        </td>
    [% END #FOREACH statistics.printOrder %]
[% END #BLOCK OKMGroupStatisticsAsHtml %]
