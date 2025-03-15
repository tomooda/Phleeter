Extension { #name : 'SpMenuPresenter' }

{ #category : '*Phleeter-Core' }
SpMenuPresenter >> asCocoaMenu [

	| cocoaMenu |
	cocoaMenu := CocoaMenu new.
	title ifNotNil: [ cocoaMenu title: title ].
	self menuGroups do: [ :group |
		group menuItems do: [ :item |
			item subMenu
				ifNotNil: [ :submenu | submenu asCocoaMenu addToMenu: cocoaMenu ]
				ifNil: [
				cocoaMenu addItemWithTitle: item name action: item action ] ] ].
	^ cocoaMenu
]
