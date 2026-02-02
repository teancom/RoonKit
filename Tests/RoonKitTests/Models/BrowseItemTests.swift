import Testing
@testable import RoonKit

@Suite("BrowseItem Tests")
struct BrowseItemTests {

    @Test("BrowseItem parses complete data")
    func browseItemParsesComplete() {
        let dict: [String: Any] = [
            "title": "Album Name",
            "subtitle": "Artist Name",
            "image_key": "img-123",
            "item_key": "item-456",
            "hint": "list",
            "input_prompt": [
                "prompt": "Search",
                "action": "Go",
                "value": "",
                "is_password": false
            ]
        ]

        let item = BrowseItem(from: dict)

        #expect(item != nil)
        #expect(item?.title == "Album Name")
        #expect(item?.subtitle == "Artist Name")
        #expect(item?.imageKey == "img-123")
        #expect(item?.itemKey == "item-456")
        #expect(item?.hint == .list)
        #expect(item?.inputPrompt?.prompt == "Search")
    }

    @Test("BrowseItem parses minimal data")
    func browseItemParsesMinimal() {
        let dict: [String: Any] = [
            "title": "Play All",
            "item_key": "action-play"
        ]

        let item = BrowseItem(from: dict)

        #expect(item != nil)
        #expect(item?.title == "Play All")
        #expect(item?.subtitle == nil)
        #expect(item?.hint == BrowseItemHint.none)
    }

    @Test("BrowseItem returns nil for missing required fields")
    func browseItemReturnsNilForMissingFields() {
        let dict: [String: Any] = [
            "title": "Missing Key"
            // Missing item_key
        ]

        let item = BrowseItem(from: dict)

        #expect(item == nil)
    }

    @Test("BrowseItem hint detection works")
    func browseItemHintDetection() {
        let listItem = BrowseItem(title: "Albums", itemKey: "k1", hint: .list)
        let actionItem = BrowseItem(title: "Play", itemKey: "k2", hint: .action)
        let headerItem = BrowseItem(title: "Section", itemKey: "k3", hint: .header)

        #expect(listItem.isNavigable == true)
        #expect(listItem.isAction == false)

        #expect(actionItem.isNavigable == false)
        #expect(actionItem.isAction == true)

        #expect(headerItem.isHeader == true)
        #expect(headerItem.isNavigable == false)
    }

    @Test("BrowseItemHint decodes correctly")
    func browseItemHintDecodes() {
        #expect(BrowseItemHint(rawValue: "") == BrowseItemHint.none)
        #expect(BrowseItemHint(rawValue: "action") == BrowseItemHint.action)
        #expect(BrowseItemHint(rawValue: "action_list") == BrowseItemHint.actionList)
        #expect(BrowseItemHint(rawValue: "list") == BrowseItemHint.list)
        #expect(BrowseItemHint(rawValue: "header") == BrowseItemHint.header)
    }
}

@Suite("BrowseList Tests")
struct BrowseListTests {

    @Test("BrowseListInfo parses complete data")
    func browseListInfoParsesComplete() {
        let dict: [String: Any] = [
            "title": "Albums",
            "count": 150,
            "subtitle": "By Artist",
            "image_key": "img-list",
            "level": 2,
            "display_offset": 0,
            "hint": "action_list"
        ]

        let list = BrowseListInfo(from: dict)

        #expect(list != nil)
        #expect(list?.title == "Albums")
        #expect(list?.count == 150)
        #expect(list?.subtitle == "By Artist")
        #expect(list?.level == 2)
    }

    @Test("BrowseListInfo parses minimal data")
    func browseListInfoParsesMinimal() {
        let dict: [String: Any] = [
            "title": "Results",
            "count": 10
        ]

        let list = BrowseListInfo(from: dict)

        #expect(list != nil)
        #expect(list?.title == "Results")
        #expect(list?.count == 10)
        #expect(list?.level == 0)
    }

    @Test("BrowseAction decodes correctly")
    func browseActionDecodes() {
        #expect(BrowseAction(rawValue: "list") == BrowseAction.list)
        #expect(BrowseAction(rawValue: "message") == BrowseAction.message)
        #expect(BrowseAction(rawValue: "none") == BrowseAction.none)
        #expect(BrowseAction(rawValue: "replace_item") == BrowseAction.replaceItem)
        #expect(BrowseAction(rawValue: "remove_item") == BrowseAction.removeItem)
    }
}

@Suite("BrowseHierarchy Tests")
struct BrowseHierarchyTests {

    @Test("BrowseHierarchy has correct raw values")
    func browseHierarchyRawValues() {
        #expect(BrowseHierarchy.browse.rawValue == "browse")
        #expect(BrowseHierarchy.albums.rawValue == "albums")
        #expect(BrowseHierarchy.artists.rawValue == "artists")
        #expect(BrowseHierarchy.playlists.rawValue == "playlists")
        #expect(BrowseHierarchy.internetRadio.rawValue == "internet_radio")
        #expect(BrowseHierarchy.search.rawValue == "search")
    }
}

@Suite("InputPrompt Tests")
struct InputPromptTests {

    @Test("InputPrompt parses complete data")
    func inputPromptParsesComplete() {
        let dict: [String: Any] = [
            "prompt": "Enter search term",
            "action": "Search",
            "value": "default",
            "is_password": false
        ]

        let prompt = InputPrompt(from: dict)

        #expect(prompt != nil)
        #expect(prompt?.prompt == "Enter search term")
        #expect(prompt?.action == "Search")
        #expect(prompt?.value == "default")
        #expect(prompt?.isPassword == false)
    }

    @Test("InputPrompt parses minimal data")
    func inputPromptParsesMinimal() {
        let dict: [String: Any] = [
            "prompt": "Search",
            "action": "Go"
        ]

        let prompt = InputPrompt(from: dict)

        #expect(prompt != nil)
        #expect(prompt?.value == nil)
        #expect(prompt?.isPassword == false)
    }
}
