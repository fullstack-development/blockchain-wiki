import { ethereum } from "@graphprotocol/graph-ts";
import {
  CreateWikiCall,
  NewBook,
  NewPerson,
  NewProduct,
  NewWiki
} from "../generated/Wiki/Wiki"
import { Author, AuthorBook, Block, Book, Manufacturer, Passport, Person, Product, WikiEntity,  } from "../generated/schema"

export function handleNewWiki(event: NewWiki): void {
  let wiki = new WikiEntity(event.params.id.toString() + "-" + event.logIndex.toString());
  wiki.owner = event.params.owner.toString();
  wiki.wikiId = event.params.id.toString();
  wiki.type = "small";
  wiki.save();
}

export function handleNewBook(event: NewBook): void {

  let author = new Author(event.params.id.toString());
  author.name = event.params.author;
  author.save();

  let book = new Book(event.params.id.toString());
  book.title = event.params.title;
  book.save();

  let authorBook = new AuthorBook((author.id).concat(book.id))
  authorBook.author = author.id;
  authorBook.book = book.id;
  authorBook.save();
  
}

export function handleNewPerson(event: NewPerson): void {

  let passport = new Passport(event.params.passport);
  passport.passportNumber = event.params.passport;
  passport.owner = event.params.name;
  passport.save();

  let person = new Person(event.params.id.toString());
  person.name = event.params.name;
  person.passport = passport.id;
  person.save();

}

export function handleNewProduct(event: NewProduct): void {

  let manufacturer = Manufacturer.load(event.params.name);

  if (manufacturer == null) {
    manufacturer = new Manufacturer(event.params.name);
    manufacturer.name = event.params.manufacturer;
    manufacturer.save();
  }

  let product = new Product(event.params.name + "-" + event.params.manufacturer);
  product.name = event.params.name;
  product.price = event.params.price;
  product.manufacturer = manufacturer.id;
  product.save();

}

export function handleCreateWiki(call: CreateWikiCall): void {
  let wiki = new WikiEntity(call.transaction.hash.toString());
  wiki.owner = call.inputs._newWiki;
  wiki.wikiId = call.inputs._wikiType;
  wiki.type = "small";
  wiki.save();
}

export function handleBlock(block: ethereum.Block): void {
  let id = block.hash.toString();
  //read smartcontract
  //create or update entities
  let entity = new Block(id)
  entity.save()
}
